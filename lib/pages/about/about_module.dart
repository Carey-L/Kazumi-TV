import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/about/about_page.dart';
import 'package:kazumi/pages/about/credits_page.dart';

final aboutModule = createModule(
  path: '/about',
  register: (c) {
    c
      ..route(
        '/',
        child: (context, state) => const AboutPage(),
      )
      ..route('/credits', child: (context, state) => const CreditsPage());
  },
);
