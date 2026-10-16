import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';

/// Modal dialog allowing the user to adjust the volume of a logged intake sip.
///
/// Enforces water-only invariants with strict validation:
/// - Volume between 5 ml and 1500 ml
/// - Inputting 0 ml prompts deletion of the sip entry
class AdjustSipDialog extends StatefulWidget {
  const AdjustSipDialog({
    super.key,
    required this.initialVolumeMl,
    required this.onSave,
    required this.onDelete,
  });

  final int initialVolumeMl;
  final ValueChanged<int> onSave;
  final VoidCallback onDelete;

  static Future<void> show({
    required BuildContext context,
    required int initialVolumeMl,
    required ValueChanged<int> onSave,
    required VoidCallback onDelete,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AdjustSipDialog(
        initialVolumeMl: initialVolumeMl,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<AdjustSipDialog> createState() => _AdjustSipDialogState();
}

class _AdjustSipDialogState extends State<AdjustSipDialog> {
  late final TextEditingController _controller;
  late int _currentVolume;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.initialVolumeMl;
    _controller = TextEditingController(text: '$_currentVolume');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateVolume(int newVol) {
    setState(() {
      _currentVolume = newVol.clamp(0, 2000);
      _controller.text = '$_currentVolume';
      _validate(_currentVolume);
    });
  }

  bool _validate(int vol) {
    if (vol == 0) {
      setState(() => _errorText = '0 ml will delete this sip entry.');
      return false;
    } else if (vol < 5) {
      setState(() => _errorText = 'Minimum sip volume is 5 ml.');
      return false;
    } else if (vol > 1500) {
      setState(() => _errorText = 'Maximum single sip is 1500 ml.');
      return false;
    } else {
      setState(() => _errorText = null);
      return true;
    }
  }

  void _handleConfirm() {
    final parsed = int.tryParse(_controller.text) ?? _currentVolume;
    if (parsed == 0) {
      Navigator.of(context).pop();
      widget.onDelete();
      return;
    }

    if (_validate(parsed)) {
      Navigator.of(context).pop();
      widget.onSave(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;

    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LiquidTokens.radiusCard),
      ),
      title: Row(
        children: [
          Icon(Icons.water_drop, color: palette.primary, size: 22),
          const SizedBox(width: LiquidTokens.spaceSm),
          Text(
            'Adjust Sip Volume',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Water Intake (ml):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: LiquidTokens.spaceSm),

          // Numeric Text Input
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
            ),
            decoration: InputDecoration(
              errorText: _errorText,
              suffixText: 'ml',
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
              ),
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val) ?? 0;
              setState(() {
                _currentVolume = parsed;
                _validate(parsed);
              });
            },
          ),
          const SizedBox(height: LiquidTokens.spaceMd),

          // Quick Delta Adjust Chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: LiquidTokens.spaceXs,
            runSpacing: LiquidTokens.spaceXs,
            children: [
              ActionChip(
                label: const Text('-50 ml'),
                onPressed: () => _updateVolume(_currentVolume - 50),
              ),
              ActionChip(
                label: const Text('-10 ml'),
                onPressed: () => _updateVolume(_currentVolume - 10),
              ),
              ActionChip(
                label: const Text('+10 ml'),
                onPressed: () => _updateVolume(_currentVolume + 10),
              ),
              ActionChip(
                label: const Text('+50 ml'),
                onPressed: () => _updateVolume(_currentVolume + 50),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
          ),
          onPressed: _handleConfirm,
          child: Text(_currentVolume == 0 ? 'Delete Sip' : 'Save Volume'),
        ),
      ],
    );
  }
}
