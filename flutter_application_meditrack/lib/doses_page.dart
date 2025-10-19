import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';

class Medicine {
  String name;
  int freqHours;          // frequência em HORAS
  int dosePills;          // quantas pílulas por dose
  int pillsInDispenser;   // pílulas disponíveis no dispenser

  Medicine({
    required this.name,
    required this.freqHours,
    required this.dosePills,
    required this.pillsInDispenser,
  });

  Medicine copyWith({
    String? name,
    int? freqHours,
    int? dosePills,
    int? pillsInDispenser,
  }) {
    return Medicine(
      name: name ?? this.name,
      freqHours: freqHours ?? this.freqHours,
      dosePills: dosePills ?? this.dosePills,
      pillsInDispenser: pillsInDispenser ?? this.pillsInDispenser,
    );
  }
}

class DosesPage extends StatefulWidget {
  const DosesPage({super.key});

  @override
  State<DosesPage> createState() => _DosesPageState();
}

class _DosesPageState extends State<DosesPage> {
  // MOCK inicial
  final List<Medicine> _items = [
    Medicine(name: 'Alprazolam', freqHours: 6,  dosePills: 2, pillsInDispenser: 30),
    Medicine(name: 'Losartana',  freqHours: 12, dosePills: 1, pillsInDispenser: 24),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'MEDITRACK',
          style: theme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: .5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (int i = 0; i < _items.length; i++) ...[
            _MedicineCard(
              medicine: _items[i],
              onChange: () => _openEditMedicineSheet(index: i),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: AppColors.primary.withOpacity(.35),
              ),
              onPressed: _openAddMedicineSheet,
              child: Text(
                'Adicionar novo remédio',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======= AÇÕES =======

  void _openAddMedicineSheet() async {
    final created = await showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) => const MedicineFormSheet(title: 'Novo remédio'),
    );
    if (created != null && mounted) {
      setState(() => _items.add(created));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Salvo: ${created.name}')));
    }
  }

  void _openEditMedicineSheet({required int index}) async {
    final edited = await showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) => MedicineFormSheet(
        title: 'Alterar definições',
        initial: _items[index],
      ),
    );
    if (edited != null && mounted) {
      setState(() => _items[index] = edited);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Atualizado: ${edited.name}')));
    }
  }
}

// ========= FORM DENTRO DO BOTTOM SHEET =========

class MedicineFormSheet extends StatefulWidget {
  final String title;
  final Medicine? initial;
  const MedicineFormSheet({super.key, required this.title, this.initial});

  @override
  State<MedicineFormSheet> createState() => _MedicineFormSheetState();
}

class _MedicineFormSheetState extends State<MedicineFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _freqCtrl;
  late final TextEditingController _doseCtrl;
  late final TextEditingController _pillsCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.initial?.name ?? '');
    _freqCtrl  = TextEditingController(
      text: widget.initial != null ? widget.initial!.freqHours.toString() : '',
    );
    _doseCtrl  = TextEditingController(
      text: widget.initial != null ? widget.initial!.dosePills.toString() : '',
    );
    _pillsCtrl = TextEditingController(
      text: widget.initial != null ? widget.initial!.pillsInDispenser.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _freqCtrl.dispose();
    _doseCtrl.dispose();
    _pillsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final med = Medicine(
      name: _nameCtrl.text.trim(),
      freqHours: int.parse(_freqCtrl.text),
      dosePills: int.parse(_doseCtrl.text),
      pillsInDispenser: int.parse(_pillsCtrl.text),
    );
    Navigator.of(context).pop<Medicine>(med);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Nome do remédio'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _freqCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Frequência (em horas)'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Informe um número válido (> 0)';
                if (n > 48) return 'Valor muito alto (máx. 48h)';
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _doseCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Dose (pílulas por tomada)'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Informe um número válido (> 0)';
                if (n > 10) return 'Valor muito alto';
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _pillsCtrl,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Pílulas no dispenser'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Informe um número válido (>= 0)';
                if (n > 500) return 'Valor muito alto';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  'Salvar',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ========= CARD =========

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onChange;

  const _MedicineCard({
    required this.medicine,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // LADO ESQUERDO
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medicine.name,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4A4485),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 6),
                  Text('Frequência',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF7E7E8A),
                        fontSize: 13,
                      )),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${medicine.freqHours} ',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          )),
                      Text('hrs',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black87,
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // LADO DIREITO
          Expanded(
            child: Container(
              height: 150,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.lightbulb_outline, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${medicine.pillsInDispenser} pílulas no dispenser',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6C6B77),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text('Dose',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      )),
                  Text(
                    '${medicine.dosePills} pílulas',
                    style: GoogleFonts.poppins(color: const Color(0xFF6C6B77)),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 36,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2F2941),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: onChange,
                      child: Text(
                        'Alterar definições',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
