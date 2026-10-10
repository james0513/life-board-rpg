import 'json_checks.dart';
import 'player.dart';

class LifeEvent {
  final String id, title, description;
  final StatDelta effects;
  const LifeEvent({required this.id, required this.title,
    required this.description, required this.effects});
  factory LifeEvent.fromJson(Map<String, dynamic> json) {
    checkKeys(json, {'id', 'title', 'description', 'effects'}, 'event');
    return LifeEvent(id: jsonText(json['id'], 'event.id'),
      title: jsonText(json['title'], 'event.title'),
      description: jsonText(json['description'], 'event.description'),
      effects: StatDelta.fromJson(jsonObject(json['effects'], 'event.effects')));
  }
}

class EventOutcome {
  final LifeEvent event;
  final Player player;
  final StatDelta applied;
  const EventOutcome(this.event, this.player, this.applied);
}
