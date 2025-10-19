import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_meditrack/ui/input_styles.dart';

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
    setState(() {
      list.removeAt(i);
    });
  }

  Future<void> _addOrEditDoctor({_Doctor? initial, int? index}) async {
    final result = await showModalBottomSheet<_Doctor>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'endereco': {
        'logradouro': _logradouroCtrl.text.trim(),
        'numero': _numeroCtrl.text.trim(),
        'bairro': _bairroCtrl.text.trim(),
        'cidade': _cidadeCtrl.text.trim(),
        'uf': _ufCtrl.text.trim(),
        'cep': _cepCtrl.text.trim(),
        'pais': _paisCtrl.text.trim(),
      },
      'dataNascimento': _birthDate?.toIso8601String(),
      'healthProfile': {
        'alergias': _alergias,
        'condicoesCronicas': _cronicas,
        'intoleranciasMedicamentos': _intolerancias,
        'alturaCm': double.tryParse(_alturaCtrl.text.replaceAll(',', '.')),
        'pesoKg': double.tryParse(_pesoCtrl.text.replaceAll(',', '.')),
        'obs': _obsCtrl.text.trim(),
      },
      'medTeam': _medTeam.map((d) => d.toJson()).toList(),
    };

    // mock de envio — apenas mostra o payload
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    // ignore: avoid_print
    print(pretty);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil salvo (mock).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'MEDITRACK',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: .5,
          ),
        ),
      ),
      body: SafeArea(
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
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                        decoration: inputDecoration('Nome'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.poppins(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                          final ok = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\.\-]+$')
                              .hasMatch(v.trim());
                          return ok ? null : 'E-mail inválido';
                        },
                        decoration: inputDecoration('E-mail'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(),
                        decoration: inputDecoration('Telefone (formato internacional)'),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickBirthDate,
                        child: InputDecorator(
                          decoration: inputDecoration('Data de nascimento'),
                          child: Text(
                            _birthDate == null
                                ? 'Selecionar...'
                                : DateFormat('dd/MM/yyyy', 'pt_BR').format(_birthDate!),
                            style: GoogleFonts.poppins(
                              color:
                                  _birthDate == null ? Colors.black45 : Colors.black87,
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
                        decoration: inputDecoration('Logradouro'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _numeroCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.poppins(),
                              decoration: inputDecoration('Número'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _bairroCtrl,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.poppins(),
                              decoration: inputDecoration('Bairro'),
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
                              decoration: inputDecoration('Cidade'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _ufCtrl,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.poppins(),
                              decoration: inputDecoration('UF'),
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
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.poppins(),
                              decoration: inputDecoration('CEP'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _paisCtrl,
                              textInputAction: TextInputAction.done,
                              style: GoogleFonts.poppins(),
                              decoration: inputDecoration('País'),
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
                        items: _alergias,
                        inputCtrl: _alergiaInput,
                        onAdd: () => _addChip(_alergiaInput, _alergias),
                        onDelete: (i) => _removeChip(_alergias, i),
                      ),
                      const SizedBox(height: 12),
                      _ChipsEditor(
                        label: 'Condições crônicas',
                        items: _cronicas,
                        inputCtrl: _cronicaInput,
                        onAdd: () => _addChip(_cronicaInput, _cronicas),
                        onDelete: (i) => _removeChip(_cronicas, i),
                      ),
                      const SizedBox(height: 12),
                      _ChipsEditor(
                        label: 'Intolerâncias a medicamentos',
                        items: _intolerancias,
                        inputCtrl: _intoleranciaInput,
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.poppins(),
                              decoration: inputDecoration('Altura (cm)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _pesoCtrl,
                              textInputAction: TextInputAction.done,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.poppins(),
                              decoration: inputDecoration('Peso (kg)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _obsCtrl,
                        maxLines: 4,
                        style: GoogleFonts.poppins(),
                        decoration: inputDecoration('Observações'),
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
                    onPressed: _submit,
                    child: Text(
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
 *  COMPONENTES VISUAIS
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
  final List<String> items;
  final TextEditingController inputCtrl;
  final VoidCallback onAdd;
  final void Function(int) onDelete;

  const _ChipsEditor({
    required this.label,
    required this.items,
    required this.inputCtrl,
    required this.onAdd,
    required this.onDelete,
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
                decoration: inputDecoration('Adicionar item'),
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

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'crm': crm,
        'contato': contato,
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
              style:
                  GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomeCtrl,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Nome'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _crmCtrl,
              textInputAction: TextInputAction.next,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('CRM'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o CRM' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contatoCtrl,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.poppins(),
              decoration: inputDecoration('Contato'),
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
