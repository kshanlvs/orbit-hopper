import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/progress/progress_cubit.dart';

class OrbitHopperApp extends StatelessWidget {
  const OrbitHopperApp({super.key, required this.progressCubit});

  final ProgressCubit progressCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: progressCubit,
      child: MaterialApp.router(
        title: 'Orbit Hopper',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: appRouter,
      ),
    );
  }
}
