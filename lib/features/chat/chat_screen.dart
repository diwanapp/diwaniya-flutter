import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/mock_data.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/user_service.dart';
import '../../l10n/ar.dart';

String _formatChatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(bytes >= 10 * mb ? 0 : 1)} MB';
  }
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}

IconData _chatFileIcon(String? mime, String? name) {
  final value = '${mime ?? ''} ${name ?? ''}'.toLowerCase();
  if (value.contains('pdf')) return Icons.picture_as_pdf_rounded;
  if (value.contains('word') ||
      value.endsWith('.doc') ||
      value.endsWith('.docx')) {
    return Icons.description_rounded;
  }
  if (value.contains('excel') ||
      value.endsWith('.xls') ||
      value.endsWith('.xlsx')) {
    return Icons.table_chart_rounded;
  }
  if (value.contains('powerpoint') ||
      value.endsWith('.ppt') ||
      value.endsWith('.pptx')) {
    return Icons.slideshow_rounded;
  }
  if (value.contains('zip') || value.contains('rar') || value.endsWith('.7z')) {
    return Icons.folder_zip_rounded;
  }
  return Icons.insert_drive_file_rounded;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  bool _showEmoji = false;
  bool _isRecording = false;
  bool _isSendingImage = false;
  bool _isSendingVoice = false;
  bool _isSendingFile = false;
  bool _isSendingText = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  final Stopwatch _recordStopwatch = Stopwatch();
  String? _recordingPath;
  String? _recordingDiwaniyaId;
  bool _isHydrating = false;
  String _boundDiwaniyaId = '';
  String _boundUserId = '';

  List<DiwaniyaMember> _mentionSuggestions = <DiwaniyaMember>[];
  ChatMessage? _replyTo;

  @override
  void initState() {
    super.initState();
    _boundDiwaniyaId = currentDiwaniyaId;
    _boundUserId = UserService.currentId;

    dataVersion.addListener(_onData);
    _ctrl.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _bootstrapChat(force: true);
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    dataVersion.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    final did = currentDiwaniyaId;
    final uid = UserService.currentId;

    if (did != _boundDiwaniyaId || uid != _boundUserId) {
      _boundDiwaniyaId = did;
      _boundUserId = uid;
      unawaited(_bootstrapChat(force: true));
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrapChat({bool force = false}) async {
    final did = currentDiwaniyaId;
    if (did.isEmpty || !mounted) return;

    setState(() => _isHydrating = true);

    try {
      if (force) {
        await ChatService.syncForDiwaniya(
          did,
          limit: ChatService.initialMessagesLimit,
        );
      } else {
        await ChatService.ensureHydrated(did);
      }

      await ChatService.markAllRead(did);
      await AppRepository.saveChat();
    } catch (_) {
      // Keep current UI stable if backend fails transiently.
    } finally {
      if (mounted) {
        setState(() => _isHydrating = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollCtrl.hasClients) {
      return;
    }
    final target = _scrollCtrl.position.maxScrollExtent;
    if (animate) {
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollCtrl.jumpTo(target);
    }
  }

  void _setReply(ChatMessage msg) {
    setState(() => _replyTo = msg);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTo = null);
  }

  ReplyInfo? get _replyInfo {
    final r = _replyTo;
    if (r == null) return null;
    return ReplyInfo(
      messageId: r.id,
      senderName: r.senderName,
      preview: ChatService.previewOf(r),
    );
  }

  void _onTextChanged() {
    final text = _ctrl.text;
    final sel = _ctrl.selection;

    if (!sel.isValid || sel.baseOffset != sel.extentOffset) {
      _setMentionSuggestions(const <DiwaniyaMember>[]);
      return;
    }

    final cursor = sel.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _setMentionSuggestions(const <DiwaniyaMember>[]);
      return;
    }

    final before = text.substring(0, cursor);
    final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(before);

    if (match == null) {
      _setMentionSuggestions(const <DiwaniyaMember>[]);
      return;
    }

    final rawQuery = (match.group(2) ?? '').trim();
    final members = ChatService.mentionCandidates(rawQuery);
    _setMentionSuggestions(members);
  }

  void _setMentionSuggestions(List<DiwaniyaMember> next) {
    if (_sameMentionList(_mentionSuggestions, next)) return;
    if (!mounted) return;
    setState(() => _mentionSuggestions = List<DiwaniyaMember>.from(next));
  }

  bool _sameMentionList(
    List<DiwaniyaMember> a,
    List<DiwaniyaMember> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name) return false;
    }
    return true;
  }

  void _restoreComposerFocus() {
    if (!mounted) return;

    void focusNow() {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusNode);
      _focusNode.requestFocus();
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    }

    focusNow();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNow();
      Future<void>.delayed(const Duration(milliseconds: 60), focusNow);
      Future<void>.delayed(const Duration(milliseconds: 180), focusNow);
      Future<void>.delayed(const Duration(milliseconds: 320), focusNow);
    });
  }

  void _insertMention(DiwaniyaMember member) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final cursor =
        sel.isValid ? sel.baseOffset.clamp(0, text.length) : text.length;
    final before = text.substring(0, cursor);
    final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(before);
    if (match == null) return;

    final start = match.start + (match.group(1)?.length ?? 0);
    final after = text.substring(cursor);
    final mention = '@${member.name} ';
    final updated = '${text.substring(0, start)}$mention$after';

    _ctrl.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + mention.length),
    );

    if (mounted) {
      setState(() {
        _mentionSuggestions = <DiwaniyaMember>[];
        _showEmoji = false;
      });
    }

    _restoreComposerFocus();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isSendingText) return;

    final reply = _replyInfo;
    setState(() {
      _isSendingText = true;
      _mentionSuggestions = <DiwaniyaMember>[];
    });

    try {
      final message = await ChatService.sendText(
        text,
        reply: reply,
      );
      if (message == null) return;

      _ctrl.clear();
      _cancelReply();
      await _persistChatOnly();
      _delayScroll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingText = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSendingImage) return;

    final did = currentDiwaniyaId;
    if (did.isEmpty) return;
    final reply = _replyInfo;
    final picked = await _picker.pickImage(source: source, imageQuality: 84);
    if (picked == null) return;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    setState(() => _isSendingImage = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final chatDir = Directory('${dir.path}/chat_media/$did');
      if (!await chatDir.exists()) {
        await chatDir.create(recursive: true);
      }

      final ext =
          picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final fileName = 'img_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final saved = await File(picked.path).copy('${chatDir.path}/$fileName');

      if (!mounted) return;

      try {
        await ChatService.sendImage(saved.path, diwaniyaId: did, reply: reply);
        if (!mounted) return;

        var albumMirrorOk = true;
        try {
          await ChatService.mirrorImageToChatAlbum(saved.path, diwaniyaId: did);
        } catch (_) {
          albumMirrorOk = false;
        }

        _cancelReply();
        if (albumMirrorOk) {
          await _persistChatAndAlbum();
        } else {
          await _persistChatOnly();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('تم إرسال الصورة، لكن تعذر حفظها في ألبوم الدردشة')),
            );
          }
        }
        if (!mounted) return;
        _delayScroll();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال الصورة')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingImage = false);
      }
    }
  }

  Future<void> _pickDocument() async {
    if (_isSendingFile) return;

    final did = currentDiwaniyaId;
    if (did.isEmpty) return;
    final reply = _replyInfo;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const <String>[
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'csv',
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
      );

      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;

      final picked = result.files.single;
      final safeName = picked.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final lowerName = safeName.toLowerCase();
      final allowedExtensions = <String>{
        '.pdf',
        '.doc',
        '.docx',
        '.xls',
        '.xlsx',
        '.ppt',
        '.pptx',
        '.txt',
        '.csv',
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
      };

      if (!allowedExtensions.any(lowerName.endsWith)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نوع الملف غير مدعوم حالياً')),
        );
        return;
      }

      const maxBytes = 4 * 1024 * 1024;
      if (picked.size > maxBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('حجم الملف أكبر من الحد المسموح لهذه الباقة')),
        );
        return;
      }

      setState(() => _isSendingFile = true);

      final dir = await getApplicationDocumentsDirectory();
      final chatDir = Directory('${dir.path}/chat_media/$did');
      if (!await chatDir.exists()) {
        await chatDir.create(recursive: true);
      }

      final saved = File(
        '${chatDir.path}/file_${DateTime.now().microsecondsSinceEpoch}_$safeName',
      );

      final sourcePath = picked.path?.trim();
      if (sourcePath != null && sourcePath.isNotEmpty) {
        final source = File(sourcePath);
        if (await source.exists()) {
          await source.copy(saved.path);
        }
      }

      if (!await saved.exists()) {
        final bytes = picked.bytes;
        if (bytes == null || bytes.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('تعذر قراءة الملف، جرّب ملفًا محفوظًا على الجهاز')),
          );
          return;
        }
        await saved.writeAsBytes(bytes, flush: true);
      }

      final savedSize = await saved.length();
      if (savedSize <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تجهيز الملف للإرسال')),
        );
        return;
      }

      if (savedSize > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('حجم الملف أكبر من الحد المسموح لهذه الباقة')),
        );
        return;
      }

      await ChatService.sendFile(
        saved.path,
        fileName: safeName,
        fileSizeBytes: savedSize,
        reply: reply,
      );

      _cancelReply();
      await _persistChatOnly();
      _delayScroll();
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تعذر إرفاق الملف، جرّب ملفًا محفوظًا على الجهاز')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الملف')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingFile = false);
      }
    }
  }

  void _showImageSourceSheet() {
    final c = context.cl;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (d) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border:
              Border(top: BorderSide(color: c.border.withValues(alpha: 0.35))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: c.t3.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _AttachmentAction(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'ملف',
                      color: const Color(0xFF60A5FA),
                      onTap: () {
                        Navigator.pop(d);
                        _pickDocument();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AttachmentAction(
                      icon: Icons.photo_library_rounded,
                      label: Ar.gallery,
                      color: const Color(0xFFA78BFA),
                      onTap: () {
                        Navigator.pop(d);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AttachmentAction(
                      icon: Icons.camera_alt_rounded,
                      label: Ar.camera,
                      color: const Color(0xFF34D399),
                      onTap: () {
                        Navigator.pop(d);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'الحد الأعلى للملف 20MB',
                style: TextStyle(fontSize: 11, color: c.t3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isSendingVoice) return;

    final did = currentDiwaniyaId;
    if (did.isEmpty) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى السماح باستخدام الميكروفون')),
        );
        return;
      }

      if (!mounted) return;

      final dir = await getTemporaryDirectory();
      final chatDir = Directory('${dir.path}/chat_media/$did');
      if (!await chatDir.exists()) {
        await chatDir.create(recursive: true);
      }

      final path =
          '${chatDir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      if (!mounted) return;

      _recordStopwatch
        ..reset()
        ..start();

      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _recordingPath = path;
        _recordingDiwaniyaId = did;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordSeconds++);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDiwaniyaId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر بدء التسجيل الصوتي')),
      );
    }
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording || _isSendingVoice) return;

    _recordTimer?.cancel();
    final reply = _replyInfo;
    final recordingDid = _recordingDiwaniyaId;
    final elapsedMs = _recordStopwatch.elapsedMilliseconds;
    _recordStopwatch.stop();
    final durationMs = elapsedMs > 0 ? elapsedMs : _recordSeconds * 1000;

    String? stoppedPath;
    try {
      stoppedPath = await _audioRecorder.stop();
    } catch (_) {
      stoppedPath = null;
    }

    final effectivePath = (stoppedPath?.trim().isNotEmpty ?? false)
        ? stoppedPath!.trim()
        : _recordingPath?.trim();

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _isSendingVoice = true;
    });

    try {
      if (effectivePath == null || effectivePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تجهيز التسجيل الصوتي')),
        );
        return;
      }

      final voiceFile = File(effectivePath);
      if (!await voiceFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تجهيز التسجيل الصوتي')),
        );
        return;
      }

      final voiceBytes = await voiceFile.length();
      if (!mounted) return;
      if (durationMs < 1000 || voiceBytes <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مدة التسجيل قصيرة جداً')),
        );
        return;
      }

      await ChatService.sendVoice(
        voiceFile.path,
        durationMs: durationMs,
        diwaniyaId: recordingDid,
        reply: reply,
      );
      if (!mounted) return;

      _cancelReply();
      await _persistChatOnly();
      if (!mounted) return;
      _delayScroll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال الرسالة الصوتية')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVoice = false;
          _recordingPath = null;
          _recordingDiwaniyaId = null;
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _recordStopwatch
      ..stop()
      ..reset();
    try {
      await _audioRecorder.stop();
    } catch (_) {
      // Recorder may already be stopped.
    }
    if (_recordingPath != null) {
      final f = File(_recordingPath!);
      if (f.existsSync()) {
        f.deleteSync();
      }
    }
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDiwaniyaId = null;
      });
    }
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _showEmoji = true);
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final cursor = sel.isValid ? sel.baseOffset : text.length;
    final newText =
        '${text.substring(0, cursor)}${emoji.emoji}${text.substring(cursor)}';
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursor + emoji.emoji.length,
      ),
    );
  }

  Future<void> _persistChatOnly() async {
    await AppRepository.saveChat();
    await AppRepository.saveActivities();
    await AppRepository.saveNotifications();
  }

  Future<void> _persistChatAndAlbum() async {
    await AppRepository.saveChat();
    await AppRepository.saveAlbum();
    await AppRepository.saveActivities();
    await AppRepository.saveNotifications();
  }

  void _delayScroll() {
    Future.delayed(
      const Duration(milliseconds: 100),
      () => _scrollToBottom(animate: true),
    );
  }

  String _fmtDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  String _dayLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final msgs = ChatService.activeMessages();
    final myId = UserService.currentId;
    final diwName =
        allDiwaniyas.where((d) => d.id == currentDiwaniyaId).firstOrNull?.name;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Ar.chat,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.t1,
              ),
            ),
            if (diwName != null)
              Text(
                diwName,
                style: TextStyle(fontSize: 12, color: c.t3),
              ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () {
          if (_showEmoji) {
            setState(() => _showEmoji = false);
            _focusNode.requestFocus();
          }
        },
        child: Column(
          children: [
            if (_isHydrating) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Icon(
                              Icons.forum_outlined,
                              size: 34,
                              color: c.accent,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            Ar.noMessages,
                            style: TextStyle(fontSize: 14, color: c.t3),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final isMine = m.senderUserId == myId;
                        final showName = !isMine &&
                            (i == 0 ||
                                msgs[i - 1].senderUserId != m.senderUserId);
                        final showDayHeader = i == 0 ||
                            !_isSameDay(msgs[i - 1].createdAt, m.createdAt);

                        return Column(
                          children: [
                            if (showDayHeader)
                              _DaySeparator(label: _dayLabel(m.createdAt)),
                            _SwipeToReply(
                              onReply: () => _setReply(m),
                              child: _ChatBubble(
                                message: m,
                                isMine: isMine,
                                showName: showName,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            _buildBottomDock(c),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDock(CL c) {
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: _showEmoji ? 0 : keyboardBottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mentionSuggestions.isNotEmpty) _buildMentionOverlay(c),
            if (_replyTo != null) _buildReplyPreview(c),
            _isRecording ? _buildRecordingBar(c) : _buildComposer(c),
            if (_showEmoji)
              Container(
                color: c.card,
                child: SizedBox(
                  height: 286,
                  child: EmojiPicker(
                    onEmojiSelected: _onEmojiSelected,
                    config: Config(
                      height: 286,
                      emojiViewConfig: const EmojiViewConfig(
                        columns: 8,
                        emojiSizeMax: 30,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        indicatorColor: c.accent,
                        iconColorSelected: c.accent,
                        iconColor: c.t3,
                        backgroundColor: c.card,
                      ),
                      searchViewConfig: SearchViewConfig(
                        buttonIconColor: c.accent,
                        backgroundColor: c.card,
                      ),
                      bottomActionBarConfig: const BottomActionBarConfig(
                        enabled: false,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(CL c) {
    final r = _replyTo!;
    final preview = ChatService.previewOf(r);
    final isMedia = r.messageType == 'image' || r.messageType == 'voice';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          top: BorderSide(color: c.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          if (isMedia)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                r.messageType == 'image'
                    ? Icons.image_rounded
                    : Icons.mic_rounded,
                size: 18,
                color: c.accent,
              ),
            ),
          if (isMedia) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.t2),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 20, color: c.t3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionOverlay(CL c) {
    return TextFieldTapRegion(
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: _mentionSuggestions.map((m) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _restoreComposerFocus(),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: m.avatarColor.withValues(alpha: 0.15),
                    child: Text(
                      m.initials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: m.avatarColor,
                      ),
                    ),
                  ),
                  title: Text(
                    m.name,
                    style: TextStyle(fontSize: 14, color: c.t1),
                  ),
                  subtitle: Text(
                    m.role == 'manager' ? Ar.manager : Ar.memberUnit,
                    style: TextStyle(fontSize: 11, color: c.t3),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '@',
                      style: TextStyle(
                        color: c.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  onTap: () => _insertMention(m),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(CL c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_ctrl, _focusNode]),
        builder: (context, _) {
          final hasText = _ctrl.text.trim().isNotEmpty;
          final isFocused = _focusNode.hasFocus;

          return Directionality(
            // Stable visual layout in RTL screens:
            // left: + then mic, center: input, right: send.
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _WhatsAppIconButton(
                  icon: Icons.add_rounded,
                  color: c.t1,
                  onTap: (_isSendingImage || _isSendingFile)
                      ? () {}
                      : _showImageSourceSheet,
                  size: 44,
                ),
                const SizedBox(width: 7),
                _WhatsAppIconButton(
                  icon: _isSendingVoice
                      ? Icons.hourglass_empty_rounded
                      : Icons.mic_none_rounded,
                  color: c.t1,
                  onTap: _isSendingVoice ? () {} : _startRecording,
                  size: 42,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(minHeight: 44),
                    decoration: BoxDecoration(
                      color: c.inputBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isFocused
                            ? c.accent.withValues(alpha: 0.78)
                            : c.border.withValues(alpha: 0.35),
                        width: isFocused ? 1.4 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.5),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        textDirection: TextDirection.ltr,
                        children: [
                          const SizedBox(width: 8),
                          _WhatsAppIconButton(
                            icon: _showEmoji
                                ? Icons.keyboard_rounded
                                : Icons.sentiment_satisfied_alt_rounded,
                            color: c.t3,
                            onTap: _toggleEmoji,
                            size: 40,
                          ),
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focusNode,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: c.t1,
                                  height: 1.25,
                                ),
                                maxLines: 5,
                                minLines: 1,
                                onTap: () {
                                  if (_showEmoji) {
                                    setState(() => _showEmoji = false);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: Ar.typeMessage,
                                  hintStyle: TextStyle(color: c.t3),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 11,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _WhatsAppIconButton(
                  icon: _isSendingText
                      ? Icons.hourglass_empty_rounded
                      : Icons.send_rounded,
                  color: hasText ? c.accent : c.t3.withValues(alpha: 0.42),
                  onTap: hasText && !_isSendingText ? _send : () {},
                  size: 42,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordingBar(CL c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.errorM,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 20, color: c.error),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _fmtDuration(_recordSeconds),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.t1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    Ar.recording,
                    style: TextStyle(fontSize: 13, color: c.t2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _stopAndSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  final VoidCallback onReply;
  final Widget child;

  const _SwipeToReply({
    required this.onReply,
    required this.child,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dragOffset = 0;
  bool _triggered = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final delta = details.primaryDelta ?? 0;
    final replyDelta = isRtl ? -delta : delta;

    if (replyDelta <= 0) return;

    setState(() {
      _dragOffset = (_dragOffset + replyDelta).clamp(0, 64).toDouble();
    });

    if (!_triggered && _dragOffset >= 46) {
      _triggered = true;
      widget.onReply();
    }
  }

  void _handleDragEnd([DragEndDetails? _]) {
    if (!mounted) return;
    setState(() {
      _dragOffset = 0;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final signedOffset = isRtl ? -_dragOffset : _dragOffset;
    final c = context.cl;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: _handleDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            start: isRtl ? null : 14,
            end: isRtl ? 14 : null,
            child: Opacity(
              opacity: (_dragOffset / 64).clamp(0.0, 1.0),
              child: Icon(
                Icons.reply_rounded,
                color: c.accent,
                size: 22,
              ),
            ),
          ),
          AnimatedSlide(
            duration: _dragOffset == 0
                ? const Duration(milliseconds: 160)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            offset: Offset(signedOffset / 320, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _WhatsAppIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _WhatsAppIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size >= 44 ? 30 : 26, color: color),
      ),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.inputBg.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.t2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final String label;

  const _DaySeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.divider)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: c.t3),
            ),
          ),
          Expanded(child: Divider(color: c.divider)),
        ],
      ),
    );
  }
}

List<InlineSpan> _parseMentions(
  String text,
  Color baseColor,
  Color mentionColor,
) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'@[\u0600-\u06FF\w]+(?:\s[\u0600-\u06FF\w]+){0,3}');
  int cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: mentionColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

class _FileContent extends StatelessWidget {
  final ChatMessage message;
  final IconData icon;
  final String sizeLabel;
  final CL c;

  const _FileContent({
    required this.message,
    required this.icon,
    required this.sizeLabel,
    required this.c,
  });

  Future<void> _openFile(BuildContext context) async {
    final path = message.attachmentPath;
    if (path == null || path.trim().isEmpty) return;

    try {
      File file;
      final local = File(path);
      if (!path.startsWith('http://') &&
          !path.startsWith('https://') &&
          await local.exists()) {
        file = local;
      } else {
        final dir = await getTemporaryDirectory();
        final fileName = (message.text?.trim().isNotEmpty == true
                ? message.text!.trim()
                : 'diwaniya-file-${message.id}')
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final chatFilesDir = Directory('${dir.path}/chat_files');
        if (!await chatFilesDir.exists()) {
          await chatFilesDir.create(recursive: true);
        }
        final target = File('${chatFilesDir.path}/${message.id}_$fileName');
        file = await ApiClient.downloadToFile(path, targetFile: target);
      }

      final result = await OpenFilex.open(
        file.path,
        type: message.attachmentMimeType,
      );

      if (result.type != ResultType.done) {
        await Share.shareXFiles(
          [
            XFile(
              file.path,
              mimeType: message.attachmentMimeType,
              name: message.text?.trim().isNotEmpty == true
                  ? message.text!.trim()
                  : file.uri.pathSegments.last,
            ),
          ],
        );
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الملف. حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = message.text?.trim().isNotEmpty == true
        ? message.text!.trim()
        : 'ملف مرفق';

    return GestureDetector(
      onTap: () => _openFile(context),
      child: Container(
        width: 238,
        margin: const EdgeInsets.fromLTRB(10, 10, 10, 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.inputBg.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: c.accent, size: 23),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.t1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sizeLabel.isEmpty
                        ? 'اضغط للفتح'
                        : '$sizeLabel · اضغط للفتح',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.t3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showName;

  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.showName,
  });

  TextDirection _messageTextDirection(ChatMessage message) {
    final value = (message.text ?? '').trim();
    if (value.isEmpty) return TextDirection.rtl;

    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(value);
    final hasLatin = RegExp(r'[A-Za-z]').hasMatch(value);

    if (hasArabic) return TextDirection.rtl;
    if (hasLatin) return TextDirection.ltr;
    return TextDirection.rtl;
  }

  int _memberCount() {
    final fromApi = message.memberCount;
    if (fromApi > 0) return fromApi;
    final count = diwaniyaMembers[message.diwaniyaId]?.length ?? 1;
    return count <= 0 ? 1 : count;
  }

  int _readCount() {
    final memberCount = _memberCount();
    final fromApi = message.readCount;
    if (fromApi > 0) return fromApi.clamp(1, memberCount).toInt();
    final fallback = message.readBy.length;
    if (fallback <= 0) return 1;
    return fallback.clamp(1, memberCount).toInt();
  }

  Widget _readCounter(CL c) {
    final readCount = _readCount();
    final memberCount = _memberCount();
    final otherMembers = (memberCount - 1).clamp(0, 9999).toInt();
    final otherReaders = (readCount - 1).clamp(0, otherMembers).toInt();
    final allRead = otherMembers > 0 && otherReaders >= otherMembers;
    final hasOtherReaders = otherReaders > 0;
    final color = allRead ? c.accent : c.t3.withValues(alpha: 0.86);

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: allRead ? c.accent.withValues(alpha: 0.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          Icon(
            allRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: allRead ? 13 : 12,
            color: color,
          ),
          if (!allRead && hasOtherReaders) ...[
            const SizedBox(width: 2),
            Text(
              '$otherReaders',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    final type = message.messageType;
    final textDirection = _messageTextDirection(message);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4, left: 4),
                  child: Text(
                    message.senderName,
                    textAlign: isMine ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: isMine
                      ? LinearGradient(
                          colors: [
                            c.accent.withValues(alpha: 0.14),
                            c.accent.withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  color: isMine ? null : c.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMine ? 6 : 20),
                    bottomRight: Radius.circular(isMine ? 20 : 6),
                  ),
                  border:
                      isMine ? null : Border.all(color: c.divider, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isReply) _QuotedReply(message: message, c: c),
                    if (type == 'image')
                      _ImageContent(path: message.attachmentPath, c: c),
                    if (type == 'voice')
                      _VoiceContent(
                        path: message.attachmentPath,
                        durationMs: message.attachmentDurationMs ?? 0,
                        c: c,
                      ),
                    if (type == 'file')
                      _FileContent(
                        message: message,
                        icon: _chatFileIcon(
                            message.attachmentMimeType, message.text),
                        sizeLabel:
                            _formatChatFileSize(message.attachmentSizeBytes),
                        c: c,
                      ),
                    if (type == 'text' && message.text != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                        child: RichText(
                          textDirection: textDirection,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: c.t1,
                              height: 1.55,
                            ),
                            children:
                                _parseMentions(message.text!, c.t1, c.accent),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 9),
                      child: Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.ltr,
                          children: [
                            Text(
                              time,
                              style: TextStyle(fontSize: 10, color: c.t3),
                            ),
                            _readCounter(c),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotedReply extends StatelessWidget {
  final ChatMessage message;
  final CL c;

  const _QuotedReply({
    required this.message,
    required this.c,
  });

  IconData? get _typeIcon {
    final preview = message.replyToPreview ?? '';
    if (preview == 'صورة') return Icons.image_rounded;
    if (preview == 'رسالة صوتية') return Icons.mic_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcon;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border(right: BorderSide(color: c.accent, width: 3)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: c.accent.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.replyToSenderName ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  message.replyToPreview ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.t3,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final String? path;
  final CL c;

  const _ImageContent({
    required this.path,
    required this.c,
  });

  bool get _hasPath => path != null && path!.trim().isNotEmpty;

  bool get _isRemotePath {
    if (!_hasPath) return false;
    final value = path!.trim().toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Widget _placeholder({IconData icon = Icons.broken_image_outlined}) {
    return Container(
      height: 140,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: c.t3, size: 36),
          const SizedBox(height: 6),
          Text(Ar.noPhotos, style: TextStyle(fontSize: 11, color: c.t3)),
        ],
      ),
    );
  }

  Widget _image() {
    if (!_hasPath) return _placeholder();

    final value = path!.trim();
    if (_isRemotePath) {
      return Image.network(
        value,
        headers: ChatService.mediaHeaders,
        width: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 140,
            color: c.inputBg,
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.accent,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 140,
          color: c.inputBg,
          child: Icon(Icons.broken_image_outlined, color: c.t3, size: 36),
        ),
      );
    }

    final file = File(value);
    if (!file.existsSync()) return _placeholder();

    return Image.file(
      file,
      width: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        height: 140,
        color: c.inputBg,
        child: Icon(Icons.broken_image_outlined, color: c.t3, size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPath) return _placeholder();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _FullImageView(path: path!.trim())),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260, minHeight: 110),
        margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          child: _image(),
        ),
      ),
    );
  }
}

class _VoiceContent extends StatefulWidget {
  final String? path;
  final int durationMs;
  final CL c;

  const _VoiceContent({
    required this.path,
    required this.durationMs,
    required this.c,
  });

  @override
  State<_VoiceContent> createState() => _VoiceContentState();
}

class _VoiceContentState extends State<_VoiceContent> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.durationMs);
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inMilliseconds > 0) {
        setState(() => _duration = dur);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  bool get _isRemotePath {
    final value = (widget.path ?? '').trim().toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<String?> _downloadRemoteVoice(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final headers = ChatService.mediaHeaders ?? const <String, String>{};
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chat_voice_${url.hashCode}.m4a');
      final sink = file.openWrite();
      await response.pipe(sink);
      await sink.close();
      client.close(force: true);
      if (await file.exists() && await file.length() > 0) return file.path;
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _toggle() async {
    final rawPath = widget.path?.trim();
    if (rawPath == null || rawPath.isEmpty) return;

    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    final playablePath =
        _isRemotePath ? await _downloadRemoteVoice(rawPath) : rawPath;
    if (playablePath == null || !File(playablePath).existsSync()) return;

    await _player.play(DeviceFileSource(playablePath));
    if (mounted) setState(() => _playing = true);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(color: c.accent, shape: BoxShape.circle),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress,
                      color: c.accent,
                      backgroundColor: c.accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _playing ? _fmt(_position) : _fmt(_duration),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.t2,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.mic_rounded,
                      size: 14,
                      color: c.accent.withValues(alpha: 0.55),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullImageView extends StatelessWidget {
  final String path;

  const _FullImageView({required this.path});

  bool get _isRemotePath {
    final value = path.trim().toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final value = path.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        child: Center(
          child: _isRemotePath
              ? Image.network(
                  value,
                  headers: ChatService.mediaHeaders,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 64,
                  ),
                )
              : Image.file(
                  File(value),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 64,
                  ),
                ),
        ),
      ),
    );
  }
}
