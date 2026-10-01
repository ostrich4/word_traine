import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding
      .ensureInitialized();

  runApp(
    const WordTrainerApp(),
  );
}

class WordTrainerApp
    extends StatelessWidget {
  const WordTrainerApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      title:
          'Тренажёр иностранных слов',

      debugShowCheckedModeBanner:
          false,

      theme: ThemeData(
        useMaterial3: true,

        colorSchemeSeed:
            const Color(
          0xFF6750A4,
        ),

        scaffoldBackgroundColor:
            const Color(
          0xFFF8F7FB,
        ),

        appBarTheme:
            const AppBarTheme(
          centerTitle: false,
        ),

        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,

          fillColor:
              Colors.white,

          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),

            borderSide:
                BorderSide.none,
          ),
        ),
      ),

      home:
          const HomeScreen(),
    );
  }
}
