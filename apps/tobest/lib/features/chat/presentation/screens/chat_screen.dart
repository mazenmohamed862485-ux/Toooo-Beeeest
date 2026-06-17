// apps/tobest/lib/features/chat/presentation/screens/chat_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/design/tokens.dart';
import 'package:shared/domain/entities/chat_entity.dart';
import 'package:shared/infrastructure/gas_client.dart';
import 'package:shared/data/models/chat_model.dart';
import 'package:shared/infrastructure/isar_service.dart';
import 'package:shared/infrastructure/polling_service.dart';
import 'package:tobest/features/auth/presentation/providers/auth_provider.dart';
import 'package:tobest/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:tobest/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:uuid/uuid.dart';

part 'chat_screen.g.dart';

/// مزود رسائل المحادثة مع Polling
@riverpod
class ChatMessages extends _$ChatMessages {
  Timer? _pollTimer;

  @override
  Future<List<ChatMessage>> build(String conversationId) async {
    ref.onDispose(() => _pollTimer?.cancel());
    await _startPolling(conversationId);
    return _fetchMessages(conversationId);
  }

  Future<List<ChatMessage>> _fetchMessages(String convId) async {
    final isar = await ref.read(isarServiceProvider.future);
    final gas  = await ref.read(gasClientProvider.future);

    // جلب من GAS
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final resp  = await gas.get<Map<String, dynamic>>(
        '/chat/messages',
        queryParameters: {
          'conversationId': convId,
          'since':          since.toIso8601String(),
        },
      );

      final list = resp.data?['messages'] as List<dynamic>? ?? [];
      final messages = list
          .map((m) => _parseMessage(m as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

      // حفظ في Isar للـ Offline
      if (messages.isNotEmpty) {
        await isar.saveMessages(
            messages.map(ChatMessageModel.fromEntity).toList());
      }
      return messages;
    } catch (_) {
      // Fallback للـ Cache
      final cached = await isar.getMessages(convId);
      return cached.map((m) => m.toEntity()).toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    }
  }

  Future<void> _startPolling(String convId) async {
    final polling = ref.read(pollingServiceProvider(_poll));
    polling.start();
  }

  Future<void> _poll() async {
    final current = state.valueOrNull ?? [];
    final gas     = await ref.read(gasClientProvider.future);
    final convId  = (state as AsyncData<List<ChatMessage>>?)
        ?.value
        .firstOrNull
        ?.conversationId;
    if (convId == null) return;

    final lastMsg = current.isNotEmpty ? current.last : null;
    final since   = lastMsg?.sentAt ?? DateTime.now().subtract(const Duration(hours: 1));

    final resp = await gas.get<Map<String, dynamic>>(
      '/chat/messages',
      queryParameters: {
        'conversationId': convId,
        'since':          since.toIso8601String(),
      },
    );

    final newMsgs = (resp.data?['messages'] as List<dynamic>? ?? [])
        .map((m) => _parseMessage(m as Map<String, dynamic>))
        .where((m) => !current.any((c) => c.id == m.id))
        .toList();

    if (newMsgs.isNotEmpty) {
      state = AsyncData([...current, ...newMsgs]
          ..sort((a, b) => a.sentAt.compareTo(b.sentAt)));
    }
  }

  /// إرسال رسالة نصية
  Future<void> sendMessage(String content) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final convId = _getConvId();
    if (convId == null) return;

    final tempMsg = ChatMessage(
      id:             const Uuid().v4(),
      conversationId: convId,
      senderId:       user.id,
      senderRole:     user.role,
      content:        content,
      sentAt:         DateTime.now(),
    );

    // Optimistic Update
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, tempMsg]);

    try {
      final gas  = await ref.read(gasClientProvider.future);
      final resp = await gas.post<Map<String, dynamic>>(
        '/chat/send',
        data: {
          'conversationId': convId,
          'senderId':       user.id,
          'senderRole':     user.role,
          'content':        content,
          'messageType':    'text',
        },
      );

      // استبدال الرسالة المؤقتة بالحقيقية
      final confirmed = _parseMessage(resp.data?['message'] as Map<String, dynamic>? ?? {});
      final updated   = current.where((m) => m.id != tempMsg.id).toList()
        ..add(confirmed)
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      state = AsyncData(updated);
    } catch (e) {
      // rollback Optimistic Update
      state = AsyncData(current);
    }
  }

  /// حذف رسالة
  Future<void> deleteMessage(String messageId) async {
    final gas  = await ref.read(gasClientProvider.future);
    await gas.delete('/chat/message/$messageId');
    final updated = (state.valueOrNull ?? [])
        .map((m) => m.id == messageId
            ? m.copyWith(isDeleted: true, content: '🗑️')
            : m)
        .toList();
    state = AsyncData(updated);
  }

  String? _getConvId() =>
      state.valueOrNull?.firstOrNull?.conversationId;

  ChatMessage _parseMessage(Map<String, dynamic> data) => ChatMessage(
        id:             data['id'] as String? ?? const Uuid().v4(),
        conversationId: data['conversationId'] as String? ?? '',
        senderId:       data['senderId'] as String? ?? '',
        senderRole:     data['senderRole'] as String? ?? '',
        content:        data['content'] as String? ?? '',
        sentAt:         DateTime.tryParse(data['sentAt'] as String? ?? '') ??
            DateTime.now(),
        messageType: MessageType.values.firstWhere(
          (t) => t.name == data['messageType'],
          orElse: () => MessageType.text,
        ),
        isDeleted: data['isDeleted'] as bool? ?? false,
        isEdited:  data['isEdited'] as bool? ?? false,
        readAt: data['readAt'] != null
            ? DateTime.tryParse(data['readAt'] as String)
            : null,
      );
}


/// شاشة الشات
class ChatScreen extends HookConsumerWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatMessagesProvider(conversationId));
    final scrollCtrl    = useScrollController();
    final isRtl         = Directionality.of(context) == TextDirection.rtl;
    final user          = ref.watch(authStateProvider).valueOrNull;
    final theme         = Theme.of(context);

    // التمرير للأسفل عند وصول رسائل جديدة
    ref.listen(chatMessagesProvider(conversationId), (_, next) {
      if (next.hasValue && scrollCtrl.hasClients) {
        Future.delayed(AppDurations.fast, () {
          if (scrollCtrl.hasClients) {
            scrollCtrl.animateTo(
              scrollCtrl.position.maxScrollExtent,
              duration: AppDurations.normal,
              curve:    Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isRtl ? 'الشات' : 'Chat'),
        actions: [
          IconButton(
            icon:      const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── قائمة الرسائل ─────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('$e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      isRtl ? 'ابدأ المحادثة...' : 'Start the conversation...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  // نشاط المستخدم → إعادة تعيين فترة الـ Polling
                  onTap: () => ref
                      .read(pollingServiceProvider(_dummyPoll))
                      .onUserActivity(),
                  child: ListView.builder(
                    controller:  scrollCtrl,
                    padding:     const EdgeInsets.all(AppSpacing.md),
                    itemCount:   messages.length,
                    itemBuilder: (ctx, i) {
                      final msg    = messages[i];
                      final isMine = msg.senderId == user?.id;

                      return ChatBubble(
                        message: msg,
                        isMine:  isMine,
                        isRtl:   isRtl,
                        onDelete: isMine
                            ? () => ref
                                .read(chatMessagesProvider(conversationId)
                                    .notifier)
                                .deleteMessage(msg.id)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // ── شريط الإدخال ──────────────────────────────
          ChatInputBar(
            isRtl: isRtl,
            onSend: (text) {
              ref
                  .read(chatMessagesProvider(conversationId).notifier)
                  .sendMessage(text);
              // إعادة تعيين Polling بعد الإرسال
              ref
                  .read(pollingServiceProvider(_dummyPoll))
                  .onUserActivity();
            },
            onImage: () {
              // اختيار صورة
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _dummyPoll() async {}
}
