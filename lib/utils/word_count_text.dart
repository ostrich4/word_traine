String wordCountText(int count) {
  final absolute = count.abs();
  final mod100 = absolute % 100;
  final mod10 = absolute % 10;

  String form;

  if (mod100 >= 11 && mod100 <= 14) {
    form = 'слов';
  } else if (mod10 == 1) {
    form = 'слово';
  } else if (mod10 >= 2 && mod10 <= 4) {
    form = 'слова';
  } else {
    form = 'слов';
  }

  return '$count $form';
}
