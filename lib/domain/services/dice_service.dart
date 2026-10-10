import 'dart:math';

class DiceService {
  final Random random;
  DiceService({Random? random}) : random = random ?? Random();
  int roll() => random.nextInt(6) + 1;
}
