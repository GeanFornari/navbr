import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navbr/models/flight_log.dart';
import 'package:navbr/providers/flights_provider.dart';
import 'package:navbr/theme/app_colors.dart';

// =============================================================================
// Screen
// =============================================================================

class FlightsScreen extends ConsumerStatefulWidget {
  const FlightsScreen({super.key});

  @override
  ConsumerState<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends ConsumerState<FlightsScreen> {
  String? _selectedId;
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final flights = ref.watch(flightsProvider);
    final selected =
        _selectedId != null ? flights.where((f) => f.id == _selectedId).firstOrNull : null;

    // If the selected plan was deleted from the list, clear selection.
    if (_selectedId != null && selected == null && !_isCreating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _selectedId = null; _isCreating = false; });
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: _PlanList(
                    flights: flights,
                    selectedId: _selectedId,
                    isCreating: _isCreating,
                    onSelect: (id) => setState(() { _selectedId = id; _isCreating = false; }),
                    onNew: () => setState(() { _selectedId = null; _isCreating = true; }),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outline.withAlpha(51),
                ),
                Expanded(
                  flex: 2,
                  child: _isCreating
                      ? _PlanForm(
                          key: const ValueKey('new_plan'),
                          flight: null,
                          onSave: (f) {
                            ref.read(flightsProvider.notifier).add(f);
                            setState(() { _selectedId = f.id; _isCreating = false; });
                          },
                          onCancel: () => setState(() { _selectedId = null; _isCreating = false; }),
                        )
                      : selected != null
                          ? _PlanForm(
                              key: ValueKey(selected.id),
                              flight: selected,
                              onSave: (f) {
                                ref.read(flightsProvider.notifier).add(f);
                                setState(() => _selectedId = f.id);
                              },
                              onDelete: () {
                                ref.read(flightsProvider.notifier).delete(selected.id);
                                setState(() { _selectedId = null; _isCreating = false; });
                              },
                              onCancel: () => setState(() { _selectedId = null; _isCreating = false; }),
                            )
                          : _EmptyDetail(
                              onNew: () => setState(() { _selectedId = null; _isCreating = true; }),
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

// =============================================================================
// Header
// =============================================================================

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cockpitBackground,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.route, color: AppColors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'PLANEJAMENTO',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Plan list — left panel
// =============================================================================

class _PlanList extends StatelessWidget {
  const _PlanList({
    required this.flights,
    required this.selectedId,
    required this.isCreating,
    required this.onSelect,
    required this.onNew,
  });

  final List<FlightLog> flights;
  final String? selectedId;
  final bool isCreating;
  final void Function(String) onSelect;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          color: AppColors.cockpitBackground.withAlpha(220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Text(
                flights.isEmpty
                    ? 'SEM PLANOS'
                    : '${flights.length} PLANO${flights.length == 1 ? '' : 'S'}',
                style: const TextStyle(
                  color: AppColors.cockpitLabel,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onNew,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.add, color: AppColors.accent, size: 18),
                ),
              ),
            ],
          ),
        ),
        if (isCreating)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: AppColors.accent.withAlpha(20),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 12, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  'Novo plano...',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: flights.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum plano',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: flights.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: theme.colorScheme.outline.withAlpha(30)),
                  itemBuilder: (context, index) {
                    final f = flights[index];
                    return _PlanListItem(
                      flight: f,
                      isSelected: !isCreating && f.id == selectedId,
                      onTap: () => onSelect(f.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PlanListItem extends StatelessWidget {
  const _PlanListItem({
    required this.flight,
    required this.isSelected,
    required this.onTap,
  });

  final FlightLog flight;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withAlpha(25) : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  flight.formattedDate,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(flight.startTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected ? AppColors.accent : theme.colorScheme.outline,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(
                    flight.originLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.accent : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward, size: 11, color: theme.colorScheme.outline),
                ),
                Flexible(
                  child: Text(
                    flight.destLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.accent : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Empty detail — right panel placeholder
// =============================================================================

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 64, color: theme.colorScheme.outline.withAlpha(120)),
            const SizedBox(height: 16),
            Text(
              'Selecione ou crie um plano',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('Novo Plano'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Plan form — right panel (create or edit)
// =============================================================================

class _PlanForm extends StatefulWidget {
  const _PlanForm({
    super.key,
    required this.flight,
    required this.onSave,
    this.onDelete,
    required this.onCancel,
  });

  final FlightLog? flight;
  final void Function(FlightLog) onSave;
  final VoidCallback? onDelete;
  final VoidCallback onCancel;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  late final TextEditingController _originCtrl;
  late final TextEditingController _destCtrl;
  late final TextEditingController _altCtrl;
  late final TextEditingController _aircraftCtrl;
  late final TextEditingController _flCtrl;
  late final TextEditingController _routeCtrl;
  late DateTime _date;
  late TimeOfDay _departureTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.flight;
    _originCtrl = TextEditingController(text: f?.originIcao ?? '');
    _destCtrl = TextEditingController(text: f?.destIcao ?? '');
    _altCtrl = TextEditingController(text: f?.alternateIcao ?? '');
    _aircraftCtrl = TextEditingController(text: f?.aircraftReg ?? '');
    _flCtrl = TextEditingController(text: f?.flightLevel ?? '');
    _routeCtrl = TextEditingController(text: f?.route ?? '');
    _date = f?.startTime ?? DateTime.now();
    _departureTime = f != null
        ? TimeOfDay(hour: f.startTime.hour, minute: f.startTime.minute)
        : TimeOfDay.now();
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _altCtrl.dispose();
    _aircraftCtrl.dispose();
    _flCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickDeparture() async {
    final t = await showTimePicker(context: context, initialTime: _departureTime);
    if (t != null) setState(() => _departureTime = t);
  }

  void _save() {
    final startTime = DateTime(
      _date.year, _date.month, _date.day,
      _departureTime.hour, _departureTime.minute,
    );

    final f = FlightLog(
      id: widget.flight?.id ?? startTime.millisecondsSinceEpoch.toString(),
      startTime: startTime,
      originIcao: _originCtrl.text.trim().isEmpty ? null : _originCtrl.text.trim(),
      destIcao: _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim(),
      alternateIcao: _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
      aircraftReg: _aircraftCtrl.text.trim().isEmpty ? null : _aircraftCtrl.text.trim(),
      flightLevel: _flCtrl.text.trim().isEmpty ? null : _flCtrl.text.trim(),
      route: _routeCtrl.text.trim().isEmpty ? null : _routeCtrl.text.trim(),
    );

    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    widget.onSave(f);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir plano'),
        content: Text(
          'Excluir o plano ${widget.flight!.originLabel} → ${widget.flight!.destLabel}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      widget.onDelete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.flight == null;
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final dateLabel =
        '${_date.day.toString().padLeft(2, '0')} ${months[_date.month - 1]} ${_date.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(
                isNew ? Icons.add_circle_outline : Icons.route,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                isNew
                    ? 'NOVO PLANO'
                    : '${widget.flight!.originLabel}  →  ${widget.flight!.destLabel}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // L1: DATA / HORA(ETD)
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'DATA',
                        value: dateLabel,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.schedule_outlined,
                        label: 'HORA (ETD)',
                        value: _departureTime.format(context),
                        onTap: _pickDeparture,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // L2: AERONAVE / FL
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _aircraftCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [_UpperCaseFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'AERONAVE',
                          hintText: 'PR-XXX',
                          counterText: '',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.airplanemode_active_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _flCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [_UpperCaseFormatter()],
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'FL',
                          hintText: 'FL100',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // L3: Origem / Destino / Alternativa
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _originCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [_UpperCaseFormatter()],
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'ORIGEM',
                          hintText: 'SBGR',
                          counterText: '',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flight_takeoff_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _destCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [_UpperCaseFormatter()],
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'DESTINO',
                          hintText: 'SBGL',
                          counterText: '',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flight_land_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _altCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [_UpperCaseFormatter()],
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'ALTERNATIVA',
                          hintText: 'SBSP',
                          counterText: '',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.alt_route_outlined, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // L4: Rota
                TextField(
                  controller: _routeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [_UpperCaseFormatter()],
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ROTA',
                    hintText: 'SBGR VCP BRS SBGL',
                    border: OutlineInputBorder(),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Icon(Icons.route_outlined, size: 18),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),
                if (!isNew && widget.onDelete != null) ...[
                  OutlinedButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Excluir plano'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.black,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isNew ? 'CRIAR PLANO' : 'SALVAR ALTERAÇÕES',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withAlpha(128)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase(), selection: n.selection);
}
