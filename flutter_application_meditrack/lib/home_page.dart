import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_meditrack/pharmacy_near_you.dart'; // tela do mapa de farmácias
import 'package:flutter_application_meditrack/doses_page.dart';        // NOVO: tela de doses
import 'package:flutter_application_meditrack/profile_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';

class Dose {
  final String medName;
  final DateTime dateTime;
  const Dose(this.medName, this.dateTime);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ---------- Mock ----------
  late final Map<DateTime, List<Dose>> _dosesByDay;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // ---------- Próxima dose / contador ----------
  Timer? _ticker;
  Duration? _nextIn;

  // ---------- Bottom nav ----------
  int _navIndex = 1; // 0=DOSES, 1=HOME, 2=PERFIL

  @override
  void initState() {
    super.initState();
    _dosesByDay = _buildMock();               // carrega mock
    _computeNextDose();                       // calcula próxima dose
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _computeNextDose());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // Normaliza a data para chave do mapa (sem hora)
  DateTime _keyOf(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, List<Dose>> _buildMock() {
    // Mock simples: 10 dias a partir de hoje, 3 doses fixas
    final names = ['Alprazolam', 'Losartana', 'Ibuprofeno'];
    final map = <DateTime, List<Dose>>{};
    final now = DateTime.now();

    for (int i = 0; i < 10; i++) {
      final day = DateTime(now.year, now.month, now.day + i);

      final doses = <Dose>[
        Dose(names[0], DateTime(day.year, day.month, day.day, 8, 30)),
        Dose(names[1], DateTime(day.year, day.month, day.day, 16, 30)),
        Dose(names[2], DateTime(day.year, day.month, day.day, 23, 30)),
      ];
      map[_keyOf(day)] = doses;
    }
    return map;
  }

  List<Dose> _eventsLoader(DateTime day) => _dosesByDay[_keyOf(day)] ?? const [];

  void _computeNextDose() {
    final now = DateTime.now();
    final upcoming = _dosesByDay.values
        .expand((e) => e)
        .where((d) => d.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (upcoming.isEmpty) {
      setState(() => _nextIn = null);
    } else {
      setState(() => _nextIn = upcoming.first.dateTime.difference(now));
    }
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')} hrs '
           '${m.toString().padLeft(2, '0')} min '
           '${s.toString().padLeft(2, '0')} seg';
  }

  void _openDosesForDay(DateTime day) {
    final doses = _eventsLoader(day);
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          children: [
            // Data grande à esquerda
            Container(
              width: 86,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('${day.day}',
                      style: GoogleFonts.poppins(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      )),
                  Text(
                    DateFormat.MMMM('pt_BR').format(day).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B6B75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Lista de doses
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(238, 221, 214, 253),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doses por vir',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 12),
                    if (doses.isEmpty)
                      Text('Sem doses para este dia.',
                          style: GoogleFonts.poppins(color: const Color.fromARGB(255, 0, 0, 0)))
                    else
                      ...doses.map((d) {
                        final h = DateFormat.Hm('pt_BR').format(d.dateTime);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              children: [
                                TextSpan(text: '${d.medName}\n'),
                                const WidgetSpan(child: SizedBox(height: 4)),
                                TextSpan(
                                  text: h,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat.yMMMM('pt_BR').format(_focusedDay);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'MEDITRACK',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 32,
            letterSpacing: 0,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            iconSize: 32,
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {},
          )
        ],
      ),

      // Bottom nav
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: Colors.deepPurple.shade100,
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          if (i == 0) {
            // DOSES -> abre a tela de doses
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DosesPage()),
            );
            // mantém o índice na HOME
            return;
          }
          if (i == 1) setState(() => _navIndex = 1); // HOME
          if (i == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()), // PERFIL (temporário)
            );
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.science_outlined), label: 'DOSES'),
          NavigationDestination(icon: Icon(Icons.home_outlined),   label: 'HOME'),
          NavigationDestination(icon: Icon(Icons.person_2_outlined), label: 'PERFIL'),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            // ---- Card Próxima dose ----
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Text('Próxima dose em:',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    _nextIn == null ? '—' : _fmtDuration(_nextIn!),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat.EEEE('pt_BR').format(DateTime.now()) +
                        ', ' +
                        DateFormat.d().format(DateTime.now()) +
                        ' de ' +
                        DateFormat.MMMM('pt_BR').format(DateTime.now()),
                    style: GoogleFonts.poppins(
                      color: Colors.deepPurple,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- Card Farmácias ----
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text('FARMÁCIAS PERTO DE VOCÊ',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.black87,
                      )),
                  const SizedBox(height: 4),
                  Text('Veja as farmácias próximas a sua localização',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 21, 25, 33),
                      )),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NearbyPharmaciesPage()),
                        );
                      },
                      child: Text('VEJA AQUI',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- Card Calendário ----
            _Card(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    monthTitle.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TableCalendar<Dose>(
                    locale: 'pt_BR',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      selectedDecoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Color.fromARGB(255, 169, 138, 255),
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerVisible: false,
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      weekendStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    eventLoader: _eventsLoader,
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                      _openDosesForDay(selected);
                    },
                    onPageChanged: (focused) {
                      setState(() => _focusedDay = focused);
                    },
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

// Card base com visual lilás
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color.fromARGB(238, 221, 214, 253),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
