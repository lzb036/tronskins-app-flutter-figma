import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tronskins_app/common/widgets/settings_style_app_bar.dart';
import 'package:get/get.dart';
import 'package:tronskins_app/common/utils/app_snackbar.dart';
import 'package:tronskins_app/common/widgets/app_request_loading_overlay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tronskins_app/common/storage/user_storage.dart';
import 'package:tronskins_app/controllers/help/feedback_controller.dart';
import 'package:tronskins_app/routes/app_routes.dart';

class FeedbackCreatePage extends StatefulWidget {
  const FeedbackCreatePage({super.key});

  @override
  State<FeedbackCreatePage> createState() => _FeedbackCreatePageState();
}

class _FeedbackCreatePageState extends State<FeedbackCreatePage> {
  final FeedbackController controller = Get.isRegistered<FeedbackController>()
      ? Get.find<FeedbackController>()
      : Get.put(FeedbackController());
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();

  final List<String> _imagePaths = [];
  final List<String> _imageIds = [];

  bool _uploading = false;
  bool _submitting = false;

  String _feedType = '';
  String _ticketId = '';

  static const int _maxImageCount = 5;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _feedType = args['type']?.toString() ?? '';
      _ticketId = args['id']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  bool get _isAddFeedback => _feedType == 'addFeedback';

  bool get _isChineseLocale =>
      Get.locale?.languageCode.toLowerCase().startsWith('zh') == true;

  Future<void> _pickImage() async {
    if (_uploading) return;
    if (_imagePaths.length >= _maxImageCount) {
      AppSnackbar.info(_imageLimitNotice);
      return;
    }
    setState(() => _uploading = true);
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final id = await controller.uploadImage(
        filePath: file.path,
        isReply: _isAddFeedback,
      );
      if (id != null) {
        setState(() {
          _imagePaths.add(file.path);
          _imageIds.add(id);
        });
        AppSnackbar.success(
          'app.user.feedback.message.image_upload_success'.tr,
        );
      } else {
        AppSnackbar.error('app.user.feedback.message.image_upload_failed'.tr);
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _imagePaths.length) return;
    setState(() {
      _imagePaths.removeAt(index);
      if (index < _imageIds.length) {
        _imageIds.removeAt(index);
      }
    });
  }

  Future<void> _submit() async {
    final feedbackTitle = _titleController.text.trim();
    final feedbackContext = _contextController.text.trim();
    if (!_isAddFeedback && feedbackTitle.isEmpty) {
      AppSnackbar.error('app.user.feedback.message.fill_feedback'.tr);
      return;
    }
    if (feedbackContext.isEmpty) {
      AppSnackbar.error('app.user.feedback.message.fill_feedback'.tr);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    AppRequestLoading.show();
    try {
      final user = UserStorage.getUserInfo();
      final ok = _isAddFeedback
          ? await controller.addReply(
              ticketId: _ticketId,
              context: feedbackContext,
              ids: _imageIds,
            )
          : await controller.submitFeedback(
              title: feedbackTitle,
              context: feedbackContext,
              email: user?.showEmail ?? '',
              ids: _imageIds,
            );
      if (ok) {
        AppSnackbar.success(
          _isAddFeedback
              ? 'app.user.feedback.message.reply_success'.tr
              : 'app.user.feedback.message.submit_success'.tr,
        );
        controller.loadTickets(refresh: true);
        _backToList();
      } else {
        AppSnackbar.info('app.system.message.not_open'.tr);
      }
    } finally {
      AppRequestLoading.hide();
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _backToList() {
    var found = false;
    Get.until((route) {
      if (route.settings.name == Routers.FEEDBACK_LIST) {
        found = true;
        return true;
      }
      return false;
    });
    if (!found) {
      Get.offNamed(Routers.FEEDBACK_LIST);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isAddFeedback
        ? 'app.user.feedback.additional'.tr
        : 'app.user.feedback.text'.tr;
    return Scaffold(
      backgroundColor: _FeedbackCreateStyle.pageBackground,
      appBar: SettingsStyleAppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            style: TextButton.styleFrom(
              foregroundColor: _FeedbackCreateStyle.brandBlue,
              disabledForegroundColor: _FeedbackCreateStyle.mutedText,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            child: Text('app.user.feedback.submit'.tr),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          if (!_isAddFeedback) ...[
            _buildTitleSection(),
            const SizedBox(height: 32),
          ],
          _buildDescriptionSection(),
          const SizedBox(height: 32),
          _buildImageSection(),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return _FeedbackFormSection(
      title: _titleTitle,
      required: true,
      child: _buildCounterField(
        controller: _titleController,
        maxLength: 100,
        hintText: _titleHint,
        height: 62,
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 72, 22),
        textInputAction: TextInputAction.next,
        counterBottom: 8,
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _FeedbackFormSection(
      title: _descriptionTitle,
      required: true,
      child: _buildCounterField(
        controller: _contextController,
        maxLength: 1000,
        hintText: _descriptionHint,
        height: 168,
        expands: true,
        maxLines: null,
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 34),
        textInputAction: TextInputAction.newline,
        counterBottom: 12,
      ),
    );
  }

  Widget _buildCounterField({
    required TextEditingController controller,
    required int maxLength,
    required String hintText,
    required double height,
    required EdgeInsetsGeometry contentPadding,
    required TextInputAction textInputAction,
    int? maxLines = 1,
    bool expands = false,
    double counterBottom = 10,
  }) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            expands: expands,
            textAlignVertical: TextAlignVertical.top,
            textInputAction: textInputAction,
            style: _FeedbackCreateStyle.inputTextStyle,
            decoration: _FeedbackCreateStyle.inputDecoration(
              hintText: hintText,
              contentPadding: contentPadding,
            ).copyWith(counterText: ''),
          ),
          Positioned(
            right: 16,
            bottom: counterBottom,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return Text(
                  '${value.text.length}/$maxLength',
                  style: _FeedbackCreateStyle.counterTextStyle,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return _FeedbackFormSection(
      title: _imageTitle,
      optionalLabel: _optionalLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              ..._imagePaths.asMap().entries.map((entry) {
                return _FeedbackImagePreview(
                  path: entry.value,
                  onRemove: () => _removeImage(entry.key),
                );
              }),
              if (_imagePaths.length < _maxImageCount)
                _FeedbackUploadTile(
                  label: _addImagesLabel,
                  uploading: _uploading,
                  onTap: _pickImage,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _imageLimitNotice,
              style: _FeedbackCreateStyle.noticeTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  String get _titleTitle => _isChineseLocale ? '问题标题' : 'Problem title';

  String get _titleHint => 'app.user.feedback.title_placeholder'.tr;

  String get _descriptionTitle {
    if (_isChineseLocale) {
      return _isAddFeedback ? '补充内容' : '问题内容';
    }
    return _isAddFeedback ? 'Supplementary content' : 'Problem content';
  }

  String get _descriptionHint => 'app.user.feedback.problem_placeholder'.tr;

  String get _imageTitle => _isChineseLocale ? '问题截图' : 'Problem screenshot';

  String get _optionalLabel => _isChineseLocale ? '(可选)' : '(Optional)';

  String get _addImagesLabel => _isChineseLocale ? '上传图片' : 'Image upload';

  String get _imageLimitNotice {
    if (_isChineseLocale) {
      return '最多可上传 5 张图片，如需补充更多截图，可提交后继续追加反馈。';
    }
    return 'You can upload up to 5 images. Add more screenshots after submitting if needed.';
  }
}

class _FeedbackFormSection extends StatelessWidget {
  const _FeedbackFormSection({
    required this.title,
    required this.child,
    this.optionalLabel,
    this.required = false,
  });

  final String title;
  final Widget child;
  final String? optionalLabel;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(title, style: _FeedbackCreateStyle.sectionTitleStyle),
              if (required) ...[
                const SizedBox(width: 3),
                const Text(
                  '*',
                  style: TextStyle(
                    color: _FeedbackCreateStyle.danger,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 20 / 14,
                  ),
                ),
              ],
              if (optionalLabel != null) ...[
                const SizedBox(width: 6),
                Text(
                  optionalLabel!,
                  style: _FeedbackCreateStyle.optionalTextStyle,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _FeedbackImagePreview extends StatelessWidget {
  const _FeedbackImagePreview({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: _FeedbackCreateStyle.tileDecoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(path), fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 20,
                  height: 20,
                  color: Colors.black.withValues(alpha: 0.50),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackUploadTile extends StatelessWidget {
  const _FeedbackUploadTile({
    required this.label,
    required this.uploading,
    required this.onTap,
  });

  final String label;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: uploading ? null : onTap,
        child: CustomPaint(
          foregroundPainter: const _DashedUploadBorderPainter(
            color: _FeedbackCreateStyle.uploadBorder,
            radius: 8,
            strokeWidth: 2,
          ),
          child: Container(
            width: 80,
            height: 80,
            decoration: _FeedbackCreateStyle.uploadFillDecoration,
            child: uploading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: _FeedbackCreateStyle.brandBlue,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: _FeedbackCreateStyle.actionBlue,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(label, style: _FeedbackCreateStyle.uploadLabelStyle),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _DashedUploadBorderPainter extends CustomPainter {
  const _DashedUploadBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  static const _dashLength = 5.0;
  static const _dashGap = 4.0;

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + _dashLength < metric.length
            ? distance + _dashLength
            : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dashLength + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedUploadBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _FeedbackCreateStyle {
  const _FeedbackCreateStyle._();

  static const pageBackground = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF444653);
  static const inputText = Color(0xFF0F172A);
  static const mutedText = Color(0xFF64748B);
  static const border = Color(0x4DC4C5D5);
  static const tileBackground = Color(0xFFECEEF0);
  static const uploadBorder = Color(0xFFE5E5EA);
  static const brandBlue = Color(0xFF1E40AF);
  static const actionBlue = Color(0xFF3B82F6);
  static const danger = Color(0xFFBA1A1A);

  static const sectionTitleStyle = TextStyle(
    color: text,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 20 / 14,
  );

  static const optionalTextStyle = TextStyle(
    color: mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
  );

  static const inputTextStyle = TextStyle(
    color: inputText,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const counterTextStyle = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 16.5 / 11,
  );

  static const noticeTextStyle = TextStyle(
    color: mutedText,
    fontSize: 11,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    height: 16.5 / 11,
  );

  static const uploadLabelStyle = TextStyle(
    color: mutedText,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  static InputDecoration inputDecoration({
    required String hintText,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
    ),
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: inputTextStyle.copyWith(color: mutedText),
      filled: true,
      fillColor: card,
      contentPadding: contentPadding,
      border: _inputBorder(border),
      enabledBorder: _inputBorder(border),
      focusedBorder: _inputBorder(brandBlue.withValues(alpha: 0.55)),
      errorBorder: _inputBorder(danger.withValues(alpha: 0.55)),
      focusedErrorBorder: _inputBorder(danger),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
  }

  static final tileDecoration = BoxDecoration(
    color: tileBackground,
    borderRadius: BorderRadius.circular(8),
    boxShadow: const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  static final uploadFillDecoration = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(8),
  );
}
