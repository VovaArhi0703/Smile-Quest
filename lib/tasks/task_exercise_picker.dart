import 'package:flutter/material.dart';

import '../widget/exercise_picker_sheet.dart';

const _sectionTitles = {
  '/face_exercises': 'Упражнения для мимики',
  '/cheeks_exercises': 'Упражнения для щёк',
  '/jaw_exercises': 'Упражнения для нижней челюсти',
  '/lips_exercises': 'Упражнения для губ',
  '/tongue_exercises': 'Упражнения для языка',
  '/additional_exercises': 'Дополнительные упражнения',
};

const _sectionExercises = <String, List<String>>{
  '/face_exercises': [
    'face_1',
    'face_2',
    'face_3',
    'face_4',
    'face_5',
    'face_6',
    'face_7',
    'face_8',
    'face_9',
    'face_10',
    'face_11',
    'face_12',
    'face_13',
    'face_14',
    'face_15',
  ],
  '/cheeks_exercises': [
    'cheeks_1',
    'cheeks_2',
    'cheeks_3',
    'cheeks_4',
    'cheeks_5',
  ],
  '/jaw_exercises': ['jaw_1', 'jaw_2', 'jaw_3'],
  '/lips_exercises': [
    'lips_1',
    'lips_2',
    'lips_3',
    'lips_4',
    'lips_5',
    'lips_6',
    'lips_7',
  ],
  '/tongue_exercises': [
    'tongue_1',
    'tongue_2',
    'tongue_3',
    'tongue_4',
    'tongue_5',
    'tongue_6',
    'tongue_7',
  ],
  '/additional_exercises': [
    'additional_1',
    'additional_2',
    'additional_3',
    'additional_4',
  ],
};

const _exerciseTitles = {
  'face_1': 'Поднять брови вверх, удержать',
  'face_2': 'Нахмурить брови, удержать',
  'face_3': 'Закрыть глаза (крепко–слабо)',
  'face_4': 'Поморгать',
  'face_5': 'Двигать глазным яблоком, закрыв глаза',
  'face_6': 'Прищуриться, подтягивая нижнее веко',
  'face_7': 'Поочерёдно закрывать правый и левый глаз',
  'face_8': 'Сморщить нос',
  'face_9': 'Раздувать ноздри, шевелить носом. Втягивать ноздри',
  'face_10': 'Звук «М»',
  'face_11': 'Звук «О»',
  'face_12': 'Плевать',
  'face_13': 'Звуки «У», «А»',
  'face_14': 'Рот открыт, звуки «О», «А»',
  'face_15': 'Произносить «Т», «П», «Р», «У»',
  'cheeks_1': 'Надуть обе щеки',
  'cheeks_2': 'Втянуть щеки',
  'cheeks_3': 'Надуть правую щеку, затем левую',
  'cheeks_4': 'Чередовать 1 и 2',
  'cheeks_5': 'Имитировать полоскание',
  'jaw_1': 'Рот приоткрыть, широко открыть, плотно закрыть',
  'jaw_2':
      'Движения нижней челюстью вперед, назад, вправо, влево, круговые движения',
  'jaw_3': 'Имитация жевания с открытым/ закрытым ртом',
  'lips_1': 'Вытянуть губы вперед - трубочкой',
  'lips_2': 'Движения “трубочкой”',
  'lips_3': 'Трубочка-улыбочка поочередно',
  'lips_4': 'Улыбка',
  'lips_5': 'Длинное задание',
  'lips_6': 'Захватывать зубами верхние и нижние губы',
  'lips_7': 'Оскалиться',
  'tongue_1': 'Открыть рот, язык поднять, опустить',
  'tongue_2': 'Рот открыт, язык вверх и вниз',
  'tongue_3': 'Рот открыть, язык к правому уху, к левому',
  'tongue_4': 'Облизать нижнюю, затем верхнюю губу',
  'tongue_5': 'Облизать губы по кругу',
  'tongue_6': 'Языком погладить твёрдое нёбо',
  'tongue_7': 'Длинное задание',
  'additional_1': 'Поцокать, как лошадка',
  'additional_2': 'Брать с ладони мелкие куски яблока',
  'additional_3': 'Вибрация губ (фыркать)',
  'additional_4': 'Длинное задание',
  // Saved tasks may still refer to these retired exercise cards.
  'lips_8': 'Трубочка с сомкнутыми губами 2.0',
  'lips_9': 'Сомкнуть и разомкнуть губы 2.0',
  'lips_10': 'Поднять и опустить губы по очереди 2.0',
  'lips_11': 'Улыбка вправо и влево 2.0',
  'lips_12': 'Артикуляция «У–О–А–И» 2.0',
};

String taskSectionTitle(String route) => _sectionTitles[route] ?? '';

String taskExerciseTitle(String route) {
  if (!route.startsWith('/')) return '';
  return _exerciseTitles[route.substring(1)] ?? '';
}

Future<({String sectionRoute, String exerciseRoute})?> showTaskExercisePicker(
  BuildContext context, {
  required String sectionRoute,
  required String exerciseRoute,
  Color? barrierColor,
}) async {
  final sections = {
    for (final section in _sectionTitles.entries)
      section.value: (
        route: section.key,
        exercises: {
          for (final id in _sectionExercises[section.key]!)
            taskExerciseTitle('/$id'): '/$id',
        },
      ),
  };
  final initialSection = _sectionTitles[sectionRoute];
  final initialExercise = taskExerciseTitle(exerciseRoute);
  final result = await showExercisePicker(
    context,
    sectionExercises: {
      for (final entry in sections.entries)
        entry.key: entry.value.exercises.keys.toList(),
    },
    initialSection: initialSection,
    initialExercise:
        sections[initialSection]?.exercises.containsKey(initialExercise) == true
            ? initialExercise
            : null,
    barrierColor: barrierColor,
    useTaskDesign: true,
  );
  if (result == null) return null;
  final selectedSection = sections[result.section];
  return (
    sectionRoute: selectedSection?.route ?? '',
    exerciseRoute: selectedSection?.exercises[result.exercise] ?? '',
  );
}
