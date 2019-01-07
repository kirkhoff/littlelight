import 'dart:async';
import 'dart:math';

import 'package:bungie_api/models/destiny_inventory_bucket_definition.dart';
import 'package:bungie_api/models/destiny_item_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:little_light/services/bungie-api/enums/inventory-bucket-hash.enum.dart';
import 'package:little_light/services/manifest/manifest.service.dart';
import 'package:little_light/services/profile/profile.service.dart';
import 'package:little_light/utils/inventory_utils.dart';
import 'package:little_light/widgets/item_list/bucket_header.widget.dart';
import 'package:little_light/widgets/item_list/character_info.widget.dart';
import 'package:little_light/widgets/item_list/items/inventory_item_wrapper.widget.dart';

class ItemListWidget extends StatefulWidget {
  final List<int> minimalDensityBucketHashes = [
    InventoryBucket.lostItems,
    InventoryBucket.engrams,
    InventoryBucket.shaders,
    InventoryBucket.modifications
  ];
  final suppressEmptySpaces = [
    InventoryBucket.shaders,
    InventoryBucket.modifications,
    InventoryBucket.lostItems
  ];
  final profileBuckets = [
    InventoryBucket.shaders,
    InventoryBucket.modifications
  ];
  final String characterId;
  final ManifestService manifest = new ManifestService();
  final ProfileService profile = new ProfileService();
  final EdgeInsets padding;
  final List<int> bucketHashes;
  ItemListWidget({this.padding, this.bucketHashes, this.characterId, Key key})
      : super(key: key);
  @override
  ItemListWidgetState createState() => new ItemListWidgetState();
}

class ItemListWidgetState extends State<ItemListWidget> {
  List<DestinyInventoryBucketDefinition> buckefDefs;
  List<ListItem> listIndex = [];
  StreamSubscription<ProfileEvent> subscription;

  @override
  void initState() {
    super.initState();
    buildIndex();
    subscription = widget.profile.broadcaster.listen((event) {
      if (event == ProfileEvent.RECEIVED_UPDATE) {
        buildIndex();
      }
    });
  }

  @override
  dispose() {
    subscription.cancel();
    super.dispose();
  }

  buildIndex() {
    List<DestinyItemComponent> equipment =
        widget.profile.getCharacterEquipment(widget.characterId);
    List<DestinyItemComponent> characterInventory =
        widget.profile.getCharacterInventory(widget.characterId);
    List<DestinyItemComponent> profileInventory =
        widget.profile.getProfileInventory();
    List<ListItem> listIndex = [];
    listIndex.add(new ListItem(ListItem.infoHeader, null));

    widget.bucketHashes.forEach((hash) async {
      List<DestinyItemComponent> inventory = characterInventory;
      if (widget.profileBuckets.contains(hash)) {
        inventory = profileInventory;
      }
      DestinyInventoryBucketDefinition bucketDef =
          await widget.manifest.getBucketDefinition(hash);
      List<DestinyItemComponent> equipped =
          equipment.where((item) => item.bucketHash == hash).toList();
      List<DestinyItemComponent> unequipped =
          inventory.where((item) => item.bucketHash == hash).toList();
      unequipped.sort((itemA, itemB) {
        return InventoryUtils.sortItemsByPower(itemA, itemB, widget.profile);
      });
      int bucketSize = bucketDef.itemCount;
      if (hash == InventoryBucket.subclass) {
        bucketSize = 3;
      }
      int itemCount = equipped.length + unequipped.length;
      if (widget.suppressEmptySpaces.contains(hash)) {
        bucketSize = max((itemCount / 5).ceil() * 5, 5);
      }
      listIndex
          .add(new ListItem(ListItem.bucketHeader, hash, itemCount: itemCount));
      listIndex.addAll(equipped.map((item) => new ListItem(
          ListItem.equippedItem, item.itemHash,
          itemComponent: item, bucketHash: hash)));
      listIndex.addAll(unequipped.map((item) => new ListItem(
          ListItem.unequippedItem, item.itemHash,
          itemComponent: item, bucketHash: hash)));

      int fillEmpty = bucketSize - itemCount;
      for (int i = 0; i < fillEmpty; i++) {
        listIndex
            .add(ListItem(ListItem.unequippedItem, null, bucketHash: hash));
      }
      listIndex.add(new ListItem(ListItem.spacer, hash));
      setState(() {
        this.listIndex = listIndex;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: getList(),
    );
  }

  Widget getList() {
    if (listIndex.length < 2) {
      return Container();
    }
    return StaggeredGridView.countBuilder(
      crossAxisCount: 30,
      itemCount: listIndex.length,
      itemBuilder: (BuildContext context, int index) => getItem(index),
      staggeredTileBuilder: (int index) => getTileBuilder(index),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
    );
  }

  StaggeredTile getTileBuilder(int index) {
    ListItem item = listIndex[index];
    switch (item.type) {
      case ListItem.bucketHeader:
        return StaggeredTile.extent(30, 40);
      case ListItem.equippedItem:
        return StaggeredTile.extent(30, 96);
      case ListItem.unequippedItem:
        if (item.bucketHash == InventoryBucket.subclass) {
          return StaggeredTile.extent(15, 76);
        }

        if (widget.minimalDensityBucketHashes.contains(item.bucketHash)) {
          return StaggeredTile.count(6, 6);
        }
        return StaggeredTile.extent(10, 76);
      case ListItem.spacer:
        return StaggeredTile.count(30, 6);
    }
    return StaggeredTile.extent(30, 96);
  }

  Widget getItem(int index) {
    ListItem item = listIndex[index];

    switch (item.type) {
      case ListItem.infoHeader:
        return CharacterInfoWidget(
          characterId: widget.characterId,
        );

      case ListItem.bucketHeader:
        return BucketHeaderWidget(
          hash: item?.hash,
          itemCount: item.itemCount,
        );

      case ListItem.equippedItem:
        return InventoryItemWrapperWidget(item?.itemComponent, item?.bucketHash,
            key: Key("${index}_${item.itemComponent.itemHash}"));

      case ListItem.unequippedItem:
        if (widget.minimalDensityBucketHashes.contains(item.bucketHash)) {
          return InventoryItemWrapperWidget(
              item?.itemComponent, item?.bucketHash,
              key: Key("${index}_${item.itemComponent.itemHash}"),
              density: ContentDensity.MINIMAL);
        }
        return InventoryItemWrapperWidget(item?.itemComponent, item?.bucketHash,
            key: Key("${index}_${item.itemComponent?.itemHash ?? 'empty'}"),
            density: ContentDensity.MEDIUM);

      case ListItem.spacer:
        return Container();
    }
    return Container(
        color: Colors.indigo,
        child: Text("You shouldn't be seeing this, please report"));
  }
}

class ListItem {
  static const String infoHeader = "info_header";
  static const String bucketHeader = "bucket_header";
  static const String equippedItem = "equipped_item";
  static const String unequippedItem = "unequipped_item";
  static const String spacer = "spacer";
  final String type;
  final int hash;
  final int itemCount;
  final int bucketHash;
  final DestinyItemComponent itemComponent;

  ListItem(this.type, this.hash,
      {this.itemComponent, this.itemCount, this.bucketHash});
}