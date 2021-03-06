import 'dart:async';
import 'package:bungie_api/models/destiny_inventory_item_definition.dart';
import 'package:flutter/material.dart';
import 'package:little_light/services/notification/notification.service.dart';
import 'package:little_light/widgets/common/manifest_image.widget.dart';
import 'package:little_light/widgets/common/translated_text.widget.dart';
import 'package:shimmer/shimmer.dart';

class InventoryNotificationWidget extends StatefulWidget {
  final service = NotificationService();
  final double barHeight;

  InventoryNotificationWidget(
      {Key key, this.barHeight = kBottomNavigationBarHeight})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return InventoryNotificationWidgetState();
  }
}

class InventoryNotificationWidgetState
    extends State<InventoryNotificationWidget> {
  bool _busy = false;
  String _message = "";
  Widget _infoIcons;
  StreamSubscription<NotificationEvent> subscription;

  @override
  void initState() {
    super.initState();

    subscription = widget.service.listen((event) {
      handleNotification(event);
    });

    if(widget.service.latestNotification != null){
      handleNotification(widget.service.latestNotification);
    }
  }

  void handleNotification(NotificationEvent event) async {
    if(event.type == NotificationType.localUpdate) return;
    _infoIcons = null;
    switch (event.type) {
      case NotificationType.requestedUpdate:
        _busy = true;
        _message = "Updating";
        break;

      case NotificationType.receivedUpdate:
        _busy = false;
        break;

      case NotificationType.requestedTransfer:
      print(event.item?.itemHash);
        _busy = true;
        _message = "Transferring";
        _infoIcons = SizedBox(
          width: 24,
          height: 24,
          key: Key("item_${event.item.itemHash}"),
          child: ManifestImageWidget<DestinyInventoryItemDefinition>(
              event.item.itemHash),
        );
        break;

        case NotificationType.requestedEquip:
          _busy = true;
          _message = "Equipping";
          break;

        default:
        break;
    }

    setState(() {});
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: bottomPadding + kToolbarHeight + widget.barHeight,
        child: IgnorePointer(
            child: AnimatedCrossFade(
                duration: Duration(milliseconds: 300),
                firstChild: Container(
                    alignment: Alignment.bottomCenter,
                    child: idleWidget(context),
                    height: bottomPadding + kToolbarHeight + widget.barHeight),
                secondChild: Container(
                    child: busyWidget(context),
                    height: bottomPadding + kToolbarHeight + widget.barHeight),
                crossFadeState: _busy
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst)));
  }

  Widget idleWidget(context) {
    double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Stack(fit: StackFit.expand, children: [
      Positioned(
          left: 0,
          right: 0,
          height: 2,
          bottom: bottomPadding + widget.barHeight,
          child: Container(
            color: Colors.transparent,
          ))
    ]);
  }

  Widget busyWidget(BuildContext context) {
    double bottomPadding = MediaQuery.of(context).padding.bottom;
    List<Widget> stackChildren = [
      Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding + widget.barHeight,
          child: shimmerBar(context)),
      Positioned(
          right: 8,
          bottom: bottomPadding + widget.barHeight + 10,
          child: busyText(context)),
    ];
    if (bottomPadding > 1) {
      stackChildren.add(Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: bottomPadding,
        child: bottomPaddingShimmer(context),
      ));
    }
    return Stack(fit: StackFit.expand, children: stackChildren);
  }

  Widget busyText(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.blueGrey.shade900.withOpacity(.9),
            borderRadius: BorderRadius.all(Radius.circular(16))),
        alignment: Alignment.bottomRight,
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Shimmer.fromColors(
              baseColor: Colors.blueGrey.shade400,
              highlightColor: Colors.grey.shade100,
              child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: TranslatedTextWidget(_message,
                      key: Key("inventory_notification_text_$_message"),
                      uppercase: true,
                      style: TextStyle(fontWeight: FontWeight.w700)))),
          busyIcons(context)
        ]));
  }

  Widget busyIcons(BuildContext context) {
    if (_infoIcons == null) return Container();
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 4), child: _infoIcons);
  }

  Widget shimmerBar(BuildContext context) {
    return Shimmer.fromColors(
        baseColor: Colors.blueGrey.shade700,
        highlightColor: Colors.grey.shade100,
        child: Container(height: 2, color: Colors.white));
  }

  Widget bottomPaddingShimmer(BuildContext context) {
    return Shimmer.fromColors(
        baseColor: Colors.transparent,
        highlightColor: Colors.grey.shade300,
        child: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter)),
        ));
  }
}
