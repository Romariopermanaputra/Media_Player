// Panel equalizer audio dengan 5-band EQ slider vertikal
// Mendukung preset, custom mode, dan desain glassmorphism premium
//
// CATATAN: media_kit tidak mendukung EQ secara langsung pada saat ini.
// Panel ini berfungsi sebagai UI placeholder yang siap diintegrasikan
// jika dukungan EQ ditambahkan di masa mendatang.

import 'dart:ui';

import 'package:flutter/material.dart';

/// Preset equalizer yang tersedia
enum EqPreset {
  flat('Flat'),
  rock('Rock'),
  pop('Pop'),
  jazz('Jazz'),
  classical('Classical'),
  bassBoost('Bass Boost'),
  vocal('Vocal'),
  custom('Custom');

  final String label;
  const EqPreset(this.label);
}

/// Widget panel equalizer audio dengan 5-band slider vertikal.
///
/// Fitur:
/// - 5 band frekuensi: 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz
/// - Preset: Flat, Rock, Pop, Jazz, Classical, Bass Boost, Vocal
/// - Mode Custom saat user mengubah slider manual
/// - Toggle enable/disable
/// - Desain glassmorphism premium
class EqualizerPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const EqualizerPanel({super.key, this.onClose});

  @override
  State<EqualizerPanel> createState() => _EqualizerPanelState();
}

class _EqualizerPanelState extends State<EqualizerPanel>
    with SingleTickerProviderStateMixin {
  // --- State EQ ---
  bool _isEnabled = false;
  EqPreset _currentPreset = EqPreset.flat;

  /// Nilai gain per band (-12dB hingga +12dB), dinormalisasi ke 0.0 - 1.0
  /// Index: 0=60Hz, 1=230Hz, 2=910Hz, 3=3.6kHz, 4=14kHz
  List<double> _bandValues = [0.5, 0.5, 0.5, 0.5, 0.5];

  // --- Label frekuensi ---
  static const _bandLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

  // --- Preset values (0.0 = -12dB, 0.5 = 0dB, 1.0 = +12dB) ---
  static const Map<EqPreset, List<double>> _presets = {
    EqPreset.flat: [0.5, 0.5, 0.5, 0.5, 0.5],
    EqPreset.rock: [0.7, 0.6, 0.45, 0.65, 0.75],
    EqPreset.pop: [0.55, 0.65, 0.7, 0.6, 0.55],
    EqPreset.jazz: [0.6, 0.5, 0.4, 0.55, 0.65],
    EqPreset.classical: [0.55, 0.45, 0.5, 0.6, 0.7],
    EqPreset.bassBoost: [0.85, 0.75, 0.5, 0.45, 0.45],
    EqPreset.vocal: [0.4, 0.55, 0.75, 0.7, 0.5],
  };

  // --- Animasi ---
  late final AnimationController _animController;
  late final Animation<double> _slideAnim;

  // --- Konstanta Warna ---
  static const _purple = Color(0xFF7B2FBE);
  static const _teal = Color(0xFF00BFA5);
  static const _bgCard = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Terapkan preset EQ
  void _applyPreset(EqPreset preset) {
    if (preset == EqPreset.custom) return;
    setState(() {
      _currentPreset = preset;
      _bandValues = List.from(_presets[preset]!);
    });
    // TODO: Terapkan nilai EQ ke media_kit ketika didukung
  }

  /// Update nilai band dan set ke custom jika diubah manual
  void _onBandChanged(int index, double value) {
    setState(() {
      _bandValues[index] = value;
      _currentPreset = EqPreset.custom;
    });
    // TODO: Terapkan nilai EQ ke media_kit ketika didukung
  }

  /// Konversi nilai 0.0-1.0 ke dB (-12 hingga +12)
  String _valueToDb(double value) {
    final db = ((value - 0.5) * 24).round();
    return db >= 0 ? '+${db}dB' : '${db}dB';
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnim),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: _bgCard.withValues(alpha: 0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  _buildHandle(),
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildEqualizerBands(),
                  const SizedBox(height: 20),
                  _buildPresets(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handle bar di atas panel
  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Header: judul + toggle enable/disable
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Ikon equalizer dengan gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_purple, _teal],
            ).createShader(bounds),
            child: const Icon(
              Icons.equalizer_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Equalizer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Preset aktif
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _purple.withValues(alpha: 0.2),
            ),
            child: Text(
              _currentPreset.label,
              style: TextStyle(
                color: _teal.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Toggle switch
          _buildToggle(),
        ],
      ),
    );
  }

  /// Toggle switch dengan desain premium
  Widget _buildToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isEnabled = !_isEnabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _isEnabled
              ? const LinearGradient(colors: [_purple, _teal])
              : null,
          color: _isEnabled ? null : Colors.white.withValues(alpha: 0.1),
          border: Border.all(
            color: _isEnabled
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment:
              _isEnabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: _isEnabled
                  ? [
                      BoxShadow(
                        color: _teal.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// Area slider EQ 5-band
  Widget _buildEqualizerBands() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isEnabled ? 1.0 : 0.4,
      child: AbsorbPointer(
        absorbing: !_isEnabled,
        child: SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) => _buildBandSlider(i)),
            ),
          ),
        ),
      ),
    );
  }

  /// Slider vertikal individual untuk satu band frekuensi
  Widget _buildBandSlider(int index) {
    final value = _bandValues[index];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nilai dB
        Text(
          _valueToDb(value),
          style: TextStyle(
            color: _teal.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),

        // Slider vertikal custom
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) {
              return GestureDetector(
                onVerticalDragUpdate: (details) {
                  final newValue =
                      value - (details.delta.dy / constraints.maxHeight);
                  _onBandChanged(index, newValue.clamp(0.0, 1.0));
                },
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Track background
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Garis center (0dB)
                    Positioned(
                      bottom: constraints.maxHeight * 0.5 - 0.5,
                      child: Container(
                        width: 14,
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    // Track aktif
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 50),
                      width: 6,
                      height: constraints.maxHeight * value,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _teal.withValues(alpha: 0.4),
                            _teal,
                            _purple,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Thumb dengan glow
                    Positioned(
                      bottom: (constraints.maxHeight * value) - 9,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [_purple, _teal],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _teal.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),
        // Label frekuensi
        Text(
          _bandLabels[index],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Baris tombol preset
  Widget _buildPresets() {
    // Tampilkan semua preset kecuali 'custom'
    final presets =
        EqPreset.values.where((p) => p != EqPreset.custom).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: presets.map((preset) {
          final isActive = _currentPreset == preset;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _isEnabled ? () => _applyPreset(preset) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: isActive
                      ? const LinearGradient(colors: [_purple, _teal])
                      : null,
                  color: isActive
                      ? null
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: isActive
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  preset.label,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: _isEnabled ? 0.6 : 0.3),
                    fontSize: 12,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
