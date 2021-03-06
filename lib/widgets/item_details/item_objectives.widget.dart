import 'dart:async';

import 'package:bungie_api/models/destiny_inventory_item_definition.dart';
import 'package:bungie_api/models/destiny_item_component.dart';
import 'package:bungie_api/models/destiny_item_instance_component.dart';
import 'package:bungie_api/models/destiny_objective_definition.dart';
import 'package:bungie_api/models/destiny_objective_progress.dart';
import 'package:flutter/material.dart';
import 'package:little_light/services/auth/auth.service.dart';
import 'package:little_light/services/littlelight/littlelight.service.dart';
import 'package:little_light/services/littlelight/models/tracked_objective.model.dart';
import 'package:little_light/services/notification/notification.service.dart';
import 'package:little_light/services/profile/profile.service.dart';
import 'package:little_light/widgets/common/destiny_item.stateful_widget.dart';
import 'package:little_light/widgets/common/header.wiget.dart';
import 'package:little_light/widgets/common/objective.widget.dart';
import 'package:little_light/widgets/common/translated_text.widget.dart';

class ItemObjectivesWidget extends DestinyItemStatefulWidget {
  final NotificationService broadcaster = NotificationService();
  ItemObjectivesWidget(
      DestinyItemComponent item,
      DestinyInventoryItemDefinition definition,
      DestinyItemInstanceComponent instanceInfo,
      {Key key,
      String characterId})
      : super(item, definition, instanceInfo,
            key: key, characterId: characterId);

  @override
  ItemObjectivesWidgetState createState() {
    return ItemObjectivesWidgetState();
  }
}

class ItemObjectivesWidgetState extends DestinyItemState<ItemObjectivesWidget> {
  Map<int, DestinyObjectiveDefinition> objectiveDefinitions;
  List<DestinyObjectiveProgress> itemObjectives;
  StreamSubscription<NotificationEvent> subscription;
  bool isTracking = false;

  @override
  void initState() {
    super.initState();
    loadDefinitions();
    this.updateTrackStatus();
    subscription = widget.broadcaster.listen((event) {
      if (event.type == NotificationType.receivedUpdate ||
          event.type == NotificationType.localUpdate && mounted) {
        itemObjectives =
            widget.profile.getItemObjectives(widget.item.itemInstanceId);
        setState(() {});
      }
    });
  }

  @override
  dispose() {
    subscription.cancel();
    super.dispose();
  }

  loadDefinitions() async {
    if (AuthService().isLogged) {
      itemObjectives = widget.profile.getItemObjectives(item?.itemInstanceId);
    }
    objectiveDefinitions = await widget.manifest
        .getDefinitions<DestinyObjectiveDefinition>(
            definition?.objectives?.objectiveHashes);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];
    if ((objectiveDefinitions?.length ?? 0) == 0) return Container();

    items.add(Container(
        padding: EdgeInsets.all(8),
        child: HeaderWidget(
            padding: EdgeInsets.all(0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Container(
                  padding: EdgeInsets.all(8),
                  child: TranslatedTextWidget("Objectives",
                      uppercase: true,
                      style: TextStyle(fontWeight: FontWeight.bold))),
              buildRefreshButton(context)
            ]))));
    items.addAll(buildObjectives(context));
    items.add(buildTrackButton(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items);
  }

  updateTrackStatus() async {
    var objectives = await LittleLightService().getTrackedObjectives();
    var tracked = objectives.firstWhere(
        (o) =>
            o.hash == widget.definition.hash &&
            o.type == TrackedObjectiveType.Item &&
            o.instanceId == widget.item.itemInstanceId &&
            o.characterId == widget.characterId,
        orElse: () => null);
    isTracking = tracked != null;
    if (!mounted) return;
    setState(() {});
  }

  Widget buildTrackButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      child: RaisedButton(
        color: isTracking ? Colors.green.shade600 : Colors.green.shade800,
        child: isTracking
            ? TranslatedTextWidget("Stop Tracking", key: Key("stop_tracking"))
            : TranslatedTextWidget("Track Objectives",
                key: Key("track_objectives")),
        onPressed: () {
          var service = LittleLightService();
          if (isTracking) {
            service.removeTrackedObjective(
                TrackedObjectiveType.Item, definition.hash, widget.item.itemInstanceId, widget.characterId);
          } else {
            service.addTrackedObjective(
                TrackedObjectiveType.Item, definition.hash, widget.item.itemInstanceId, widget.characterId);
          }
          updateTrackStatus();
        },
      ),
    );
  }

  buildRefreshButton(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: Stack(
          children: <Widget>[
            InkWell(
                child: Container(
                    padding: EdgeInsets.all(8), child: Icon(Icons.refresh)),
                onTap: () {
                  widget.profile.fetchProfileData(
                      components: ProfileComponentGroups.basicProfile);
                })
          ],
        ));
  }

  List<Widget> buildObjectives(BuildContext context) {
    if (itemObjectives != null) {
      return itemObjectives
          .map((objective) => buildCurrentObjective(
              context, objective.objectiveHash, objective))
          .toList();
    }
    return definition.objectives.objectiveHashes
        .map((hash) => buildCurrentObjective(context, hash))
        .toList();
  }

  Widget buildCurrentObjective(BuildContext context, int hash,
      [DestinyObjectiveProgress objective]) {
    var def = objectiveDefinitions[hash];
    return Container(
        padding: EdgeInsets.all(8),
        child: ObjectiveWidget(
          key:
              Key("objective_${objective.objectiveHash}_${objective.progress}"),
          definition: def,
          objective: objective,
        ));
  }
}
