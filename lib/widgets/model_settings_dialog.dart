import 'package:flutter/material.dart';
import 'package:write4me/models/model_parameters.dart';

class ModelSettingsDialog extends StatefulWidget {
  final ModelParameters initialParameters;
  final String modelPath;

  const ModelSettingsDialog({
    super.key,
    required this.initialParameters,
    required this.modelPath,
  });

  @override
  State<ModelSettingsDialog> createState() => _ModelSettingsDialogState();
}

class _ModelSettingsDialogState extends State<ModelSettingsDialog> {
  late ModelParameters _currentParameters;

  @override
  void initState() {
    super.initState();
    _currentParameters = widget.initialParameters;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Model Parameters'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Settings are saved separately for this model.',
                    style: TextStyle(
                      color: Colors
                          .orange, // Or Colors.red, depending on desired emphasis
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset to Default',
                  onPressed: () {
                    setState(() {
                      _currentParameters = const ModelParameters();
                    });
                  },
                ),
              ],
            ),
            _buildSlider(
              'Max Tokens',
              _currentParameters.maxTokens.toDouble(),
              10.0,
              2048.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(maxTokens: value.toInt())),
              divisions: 203,
              valueLabel: _currentParameters.maxTokens.toString(),
            ),
            _buildSlider(
              'Num GPU Layers',
              _currentParameters.numGpuLayers.toDouble(),
              0.0,
              99.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(numGpuLayers: value.toInt())),
              divisions: 99,
              valueLabel: _currentParameters.numGpuLayers.toString(),
            ),
            _buildSlider(
              'Top P',
              _currentParameters.topP,
              0.0,
              1.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(topP: value)),
              divisions: 100,
              valueLabel: _currentParameters.topP.toStringAsFixed(2),
            ),
            _buildSlider(
              'Context Size',
              _currentParameters.contextSize.toDouble(),
              128.0,
              4096.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(contextSize: value.toInt())),
              divisions: 396,
              valueLabel: _currentParameters.contextSize.toString(),
            ),
            _buildSlider(
              'Temperature',
              _currentParameters.temperature,
              0.0,
              2.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(temperature: value)),
              divisions: 200,
              valueLabel: _currentParameters.temperature.toStringAsFixed(2),
            ),
            _buildSlider(
              'Repeat Penalty',
              _currentParameters.repeatPenalty,
              1.0,
              2.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(repeatPenalty: value)),
              divisions: 100,
              valueLabel: _currentParameters.repeatPenalty.toStringAsFixed(2),
            ),
            _buildSlider(
              'Top K',
              _currentParameters.topK.toDouble(),
              1.0,
              100.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(topK: value.toInt())),
              divisions: 99,
              valueLabel: _currentParameters.topK.toString(),
            ),
            _buildSlider(
              'Min P',
              _currentParameters.minP,
              0.0,
              0.5,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(minP: value)),
              divisions: 50,
              valueLabel: _currentParameters.minP.toStringAsFixed(2),
            ),
            _buildSlider(
              'Frequency Penalty',
              _currentParameters.frequencyPenalty,
              0.0,
              2.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(frequencyPenalty: value)),
              divisions: 200,
              valueLabel:
                  _currentParameters.frequencyPenalty.toStringAsFixed(2),
            ),
            _buildSlider(
              'Presence Penalty',
              _currentParameters.presencePenalty,
              0.0,
              2.0,
              (value) => setState(() => _currentParameters =
                  _currentParameters.copyWith(presencePenalty: value)),
              divisions: 200,
              valueLabel: _currentParameters.presencePenalty.toStringAsFixed(2),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _currentParameters.autoUnloadSeconds,
              decoration: const InputDecoration(
                labelText: 'Auto-unload model',
                helperText:
                    'Releases local-model RAM after generation is idle.',
                prefixIcon: Icon(Icons.memory_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Never')),
                DropdownMenuItem(value: 60, child: Text('After 1 minute')),
                DropdownMenuItem(value: 120, child: Text('After 2 minutes')),
                DropdownMenuItem(value: 300, child: Text('After 5 minutes')),
                DropdownMenuItem(value: 600, child: Text('After 10 minutes')),
                DropdownMenuItem(value: 1800, child: Text('After 30 minutes')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _currentParameters = _currentParameters.copyWith(
                      autoUnloadSeconds: value,
                    ));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _currentParameters),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSlider(String title, double value, double min, double max,
      ValueChanged<double> onChanged,
      {int? divisions, String? valueLabel}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(valueLabel ?? value.toStringAsFixed(2)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
