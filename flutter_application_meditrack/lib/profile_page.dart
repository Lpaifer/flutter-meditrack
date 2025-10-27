import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:flutter_application_meditrack/services/user_profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // --- Dados pessoais
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _birthDate;

  // --- Endereço
  final _logradouroCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();

  // --- Perfil de saúde
  final _alturaCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  final List<String> _alergias = [];
  final _alergiaInput = TextEditingController();

  final List<String> _cronicas = [];
  final _cronicaInput = TextEditingController();

  final List<String> _intolerancias = [];
  final _intoleranciaInput = TextEditingController();

  // --- Equipe médica
  final List<_Doctor> _medTeam = [];

  // --- Estado de rede
  final _svc = UserProfileService();
  bool _loading = true;
  bool _saving = false;

  InputDecoration fixedDecoration(String label, {String? helper}) {
    return inputDecoration(label, helperText: helper)
        .copyWith(floatingLabelBehavior: FloatingLabelBehavior.always);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _logradouroCtrl.dispose();
    _numeroCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _ufCtrl.dispose();
    _cepCtrl.dispose();
    _paisCtrl.dispose();
    _alturaCtrl.dispose();
    _pesoCtrl.dispose();
    _obsCtrl.dispose();
    _alergiaInput.dispose();
    _cronicaInput.dispose();
    _intoleranciaInput.dispose();
    super.dispose();
  }

  // ================== LOAD/SAVE ==================

Future<void> _load() async {
  setState(() => _loading = true);
  try {
    final me = await _svc.getMe();
    final hp = await _svc.getHealthPT();

    // básicos
    _nameCtrl.text  = (me['name'] ?? '') as String;
    _emailCtrl.text = (me['email'] ?? '') as String;
    _phoneCtrl.text = (me['phone'] ?? '') as String;

    final birthIso = me['birthDate'] as String?;
    _birthDate = (birthIso != null && birthIso.isNotEmpty)
        ? DateTime.tryParse(birthIso)?.toLocal()
        : null;

    // endereço PT
    final addr = (me['address'] is Map) ? Map<String, dynamic>.from(me['address']) : <String, dynamic>{};
    _logradouroCtrl.text = (addr['logradouro'] ?? '') as String;
    _numeroCtrl.text     = (addr['numero'] ?? '') as String;
    _bairroCtrl.text     = (addr['bairro'] ?? '') as String;
    _cidadeCtrl.text     = (addr['cidade'] ?? '') as String;
    _ufCtrl.text         = (addr['uf'] ?? '') as String;
    _cepCtrl.text        = (addr['cep'] ?? '') as String;
    _paisCtrl.text       = (addr['pais'] ?? '') as String;

    // health PT -> UI
    _alergias
      ..clear()
      ..addAll(List<String>.from(hp['alergias'] as List));
    _cronicas
      ..clear()
      ..addAll(List<String>.from(hp['condicoesCronicas'] as List));
    _intolerancias
      ..clear()
      ..addAll(List<String>.from(hp['intoleranciasMedicamentos'] as List));

    final altura = hp['alturaCm'];
    final peso   = hp['pesoKg'];
    _alturaCtrl.text = (altura == null) ? '' : altura.toString();
    _pesoCtrl.text   = (peso == null) ? '' : peso.toString();
    _obsCtrl.text    = (hp['obs'] ?? '') as String;

    // medTeam: converte para lista com 0 ou 1 item
    _medTeam.clear();
    final medico = hp['medico'] as Map<String, dynamic>?;
    if (medico != null) {
      _medTeam.add(_Doctor(
        nome: (medico['nome'] ?? '') as String,
        crm: (medico['crm'] ?? '') as String,
        contato: (medico['contato'] ?? '') as String,
      ));
    }

    setState(() => _loading = false);
  } catch (e) {
    setState(() => _loading = false);
  }
}

Future<void> _save() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  setState(() => _saving = true);
  try {
    // PATCH /users/me (PT)
    await _svc.patchMePT(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(), // remova se o back não permitir
      phone: _phoneCtrl.text.trim(),
      birthDate: _birthDate,
      addressPT: {
        'logradouro': _logradouroCtrl.text.trim(),
        'numero': _numeroCtrl.text.trim(),
        'bairro': _bairroCtrl.text.trim(),
        'cidade': _cidadeCtrl.text.trim(),
        'uf': _ufCtrl.text.trim(),
        'cep': _cepCtrl.text.trim(),
        'pais': _paisCtrl.text.trim(),
      },
    );

    // PUT /users/me/health (PT + 1 médico)
    double? toDouble(String s) => double.tryParse(s.replaceAll(',', '.').trim());
    await _svc.putHealthPT(
      alergias: _alergias,
      condicoesCronicas: _cronicas,
      intoleranciasMedicamentos: _intolerancias,
      alturaCm: toDouble(_alturaCtrl.text),
      pesoKg: toDouble(_pesoCtrl.text),
      obs: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      medico: _medTeam.isEmpty
          ? null
          : {
              'nome': _medTeam.first.nome,
              'crm': _medTeam.first.crm,
              'contato': _medTeam.first.contato,
            },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil salvo com sucesso!')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Falha ao salvar: $e')),
    );
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}



  // ignore: unused_element
  Map<String, dynamic> _buildHealthPayload() {
    double? toDouble(String s) => double.tryParse(s.replaceAll(',', '.').trim());
    final healthProfile = {
      'allergies': _alergias,
      'chronicConditions': _cronicas,
      'drugIntolerances': _intolerancias,
      'heightCm': toDouble(_alturaCtrl.text),
      'weightKg': toDouble(_pesoCtrl.text),
      'notes': _obsCtrl.text.trim(),
    };
    final medTeam = _medTeam.map((d) => d.toJsonEN()).toList();

    // pretty log opcional
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert({
      'healthProfile': healthProfile,
      'medTeam': medTeam,
    }));

    return {
      'healthProfile': healthProfile,
      'medTeam': medTeam,
    };
  }

  // ================== UI helpers ==================

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final init = _birthDate ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      initialDate: init,
      helpText: 'Data de nascimento',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _addChip(TextEditingController ctrl, List<String> list) {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      list.add(t);
      ctrl.clear();
    });
  }

  void _removeChip(List<String> list, int i) {
    setState(() => list.removeAt(i));
    }

  Future<void> _addOrEditDoctor({_Doctor? initial, int? index}) async {
    final result = await showModalBottomSheet<_Doctor>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (context) => _DoctorSheet(initial: initial),
    );
    if (result != null) {
      setState(() {
        if (index == null) {
          _medTeam.add(result);
        } else {
          _medTeam[index] = result;
        }
      });
    }
  }

  // ================== BUILD ==================

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'MEDITRACK',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: .5,
          ),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Recarregar',
              onPressed: _load,
              icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    children: [
                      _SectionCard(
                        title: 'Dados pessoais',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.poppins(),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Informe seu nome'
                                  : null,
                              decoration: fixedDecoration('Nome'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.poppins(),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Informe o e-mail';
                                }
                                final ok = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\.\-]+$')
                                    .hasMatch(v.trim());
                                return ok ? null : 'E-mail inválido';
                              },
                              decoration: fixedDecoration('E-mail'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.poppins(),
                              decoration: fixedDecoration('Telefone (formato internacional)'),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _pickBirthDate,
                              child: InputDecorator(
                                decoration: fixedDecoration('Data de nascimento'),
                                child: Text(
                                  _birthDate == null
                                      ? 'Selecionar...'
                                      : DateFormat('dd/MM/yyyy', 'pt_BR').format(_birthDate!),
                                  style: GoogleFonts.poppins(
                                    color: _birthDate == null ? Colors.black45 : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _SectionCard(
                        title: 'Endereço',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _logradouroCtrl,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.poppins(),
                              decoration: fixedDecoration('Logradouro'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _numeroCtrl,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.text,
                                    style: GoogleFonts.poppins(),
                                    decoration: fixedDecoration('Número'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 5,
                                  child: TextFormField(
                                    controller: _bairroCtrl,
                                    textInputAction: TextInputAction.next,
                                    style: GoogleFonts.poppins(),
                                    decoration: fixedDecoration('Bairro'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _cidadeCtrl,
                                    textInputAction: TextInputAction.next,
                                    style: GoogleFonts.poppins(),
                                    decoration: fixedDecoration('Cidade'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _ufCtrl,
                                    textInputAction: TextInputAction.next,
                                    style: GoogleFonts.poppins(),
                                    decoration: fixedDecoration('UF'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _cepCtrl,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.text,
                                    style: GoogleFonts.poppins(),
                                    decoration: fixedDecoration('CEP'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: _paisCtrl,
                                    textInputAction: TextInputAction.done,
                                    style: GoogleFonts.poppins(),
                                    decoration: fixedDecoration('País'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _SectionCard(
                        title: 'Perfil de saúde',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChipsEditor(
                              label: 'Alergias',
                              inputLabel: 'Adicionar alergia',
                              items: _alergias,
                              inputCtrl: _alergiaInput,
                              decorationBuilder: fixedDecoration,
                              onAdd: () => _addChip(_alergiaInput, _alergias),
                              onDelete: (i) => _removeChip(_alergias, i),
                            ),
                            const SizedBox(height: 12),
                            _ChipsEditor(
                              label: 'Condições crônicas',
                              inputLabel: 'Adicionar condição crônica',
                              items: _cronicas,
                              inputCtrl: _cronicaInput,
                              decorationBuilder: fixedDecoration,
                              onAdd: () => _addChip(_cronicaInput, _cronicas),
                              onDelete: (i) => _removeChip(_cronicas, i),
                            ),
                            const SizedBox(height: 12),
                            _ChipsEditor(
                              label: 'Intolerâncias a medicamentos',
                              inputLabel: 'Adicionar intolerância',
                              items: _intolerancias,
                              inputCtrl: _intoleranciaInput,
                              decorationBuilder: fixedDecoration,
                              onAdd: () => _addChip(_intoleranciaInput, _intolerancias),
                              onDelete: (i) => _removeChip(_intolerancias, i),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _alturaCtrl,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: GoogleFonts.poppins(),
                                    decoration: fixedDecoration('Altura (cm)'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _pesoCtrl,
                                    textInputAction: TextInputAction.done,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: GoogleFonts.poppins(),
                                    decoration: fixedDecoration('Peso (kg)'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _obsCtrl,
                              maxLines: 4,
                              style: GoogleFonts.poppins(),
                              decoration: fixedDecoration('Observações'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _SectionCard(
                        title: 'Minha equipe médica',
                        child: Column(
                          children: [
                            for (int i = 0; i < _medTeam.length; i++) ...[
                              _DoctorTile(
                                doctor: _medTeam[i],
                                onEdit: () => _addOrEditDoctor(initial: _medTeam[i], index: i),
                                onDelete: () => setState(() => _medTeam.removeAt(i)),
                              ),
                              const SizedBox(height: 10),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: FilledButton.tonal(
                                onPressed: () => _addOrEditDoctor(),
                                child: Text('Adicionar médico', style: GoogleFonts.poppins()),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                                )
                              : Text(
                                  'Salvar',
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
            ),
    );
  }
}

/* =========================================================
 *  COMPONENTES VISUAIS (iguais aos seus)
 * =======================================================*/

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(238, 221, 214, 253),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChipsEditor extends StatelessWidget {
  final String label;
  final String inputLabel;
  final List<String> items;
  final TextEditingController inputCtrl;
  final VoidCallback onAdd;
  final void Function(int) onDelete;
  final InputDecoration Function(String label, {String? helper}) decorationBuilder;

  const _ChipsEditor({
    required this.label,
    required this.inputLabel,
    required this.items,
    required this.inputCtrl,
    required this.onAdd,
    required this.onDelete,
    required this.decorationBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: -6,
          children: [
            for (int i = 0; i < items.length; i++)
              Chip(
                label: Text(items[i], style: GoogleFonts.poppins(fontSize: 12)),
                onDeleted: () => onDelete(i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: inputCtrl,
                decoration: decorationBuilder(inputLabel),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            ),
          ],
        ),
      ],
    );
  }
}

/* ------------------ Equipe médica ------------------ */

class _Doctor {
  final String nome;
  final String crm;
  final String contato;

  _Doctor({required this.nome, required this.crm, required this.contato});

  Map<String, dynamic> toJsonEN() => {
        'name': nome,
        'license': crm,
        'contact': contato,
      };
}

class _DoctorTile extends StatelessWidget {
  final _Doctor doctor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DoctorTile({
    required this.doctor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        title: Text(doctor.nome,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'CRM: ${doctor.crm}\nContato: ${doctor.contato}',
          style: GoogleFonts.poppins(height: 1.2),
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remover',
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorSheet extends StatefulWidget {
  final _Doctor? initial;
  const _DoctorSheet({this.initial});

  @override
  State<_DoctorSheet> createState() => _DoctorSheetState();
}

class _DoctorSheetState extends State<_DoctorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _crmCtrl;
  late final TextEditingController _contatoCtrl;

  InputDecoration fixedDecoration(String label) =>
      inputDecoration(label).copyWith(floatingLabelBehavior: FloatingLabelBehavior.always);

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.initial?.nome ?? '');
    _crmCtrl = TextEditingController(text: widget.initial?.crm ?? '');
    _contatoCtrl = TextEditingController(text: widget.initial?.contato ?? '');
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _crmCtrl.dispose();
    _contatoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final d = _Doctor(
      nome: _nomeCtrl.text.trim(),
      crm: _crmCtrl.text.trim(),
      contato: _contatoCtrl.text.trim(),
    );
    Navigator.of(context).pop<_Doctor>(d);
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
            Text(
              widget.initial == null ? 'Adicionar médico' : 'Editar médico',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomeCtrl,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.poppins(),
              decoration: fixedDecoration('Nome'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _crmCtrl,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.poppins(),
              decoration: fixedDecoration('CRM'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o CRM' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contatoCtrl,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.poppins(),
              decoration: fixedDecoration('Contato'),
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
