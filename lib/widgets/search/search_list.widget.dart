import 'dart:async';

import 'package:bungie_api/models/destiny_inventory_item_definition.dart';
import 'package:bungie_api/models/destiny_item_instance_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:little_light/screens/search.screen.dart';
import 'package:little_light/services/manifest/manifest.service.dart';
import 'package:little_light/services/notification/notification.service.dart';
import 'package:little_light/services/profile/profile.service.dart';
import 'package:little_light/utils/inventory_utils.dart';
import 'package:little_light/utils/item_with_owner.dart';
import 'package:little_light/widgets/item_list/items/search_item_wrapper.widget.dart';
import 'package:little_light/widgets/search/search_filters.widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:little_light/utils/remove_diacritics.dart';

class SearchListWidget extends StatefulWidget {
  final ProfileService profile = ProfileService();
  final SearchTabData tabData;
  SearchListWidget({Key key, this.tabData}) : super(key: key);
  final NotificationService broadcaster = new NotificationService();

  @override
  SearchListWidgetState createState() => new SearchListWidgetState();
}

class SearchListWidgetState<T extends SearchListWidget> extends State<T>
    with AutomaticKeepAliveClientMixin {
  String get search => widget.tabData.searchText;
  List<ItemWithOwner> items;
  Map<int, DestinyInventoryItemDefinition> itemDefinitions;
  Map<int, DestinyInventoryItemDefinition> perkDefinitions;
  StreamSubscription<NotificationEvent> subscription;

  @override
  dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  initState() {
    super.initState();
    loadItems();
    subscription = widget.broadcaster.listen((event) {
      if (event.type == NotificationType.receivedUpdate ||
      event.type == NotificationType.localUpdate){
        loadItems();
      }
    });
  }

  loadItems() async {
    List<ItemWithOwner> allItems = [];
    ProfileService profile = ProfileService();
    ManifestService manifest = ManifestService();
    Iterable<String> charIds =
        profile.getCharacters().map((char) => char.characterId);
    charIds.forEach((charId) {
      allItems.addAll(profile
          .getCharacterEquipment(charId)
          .map((item) => ItemWithOwner(item, charId)));
      allItems.addAll(profile
          .getCharacterInventory(charId)
          .map((item) => ItemWithOwner(item, charId)));
    });
    allItems.addAll(profile
        .getProfileInventory()
        .map((item) => ItemWithOwner(item, null)));
    allItems.sort(
        (a, b) => InventoryUtils.sortDestinyItems(a.item, b.item, profile));
    items = allItems.where((item) {
      return item.item.itemInstanceId != null;
    }).toList();
    Iterable<int> hashes = allItems.map((i) => i.item.itemHash);

    Set<int> perkHashes = Set();
    items.forEach((i){
      var sockets = profile.getItemSockets(i.item.itemInstanceId);
      if(sockets == null) return;
      sockets.forEach((s){
        if(s.plugHash!= null) perkHashes.add(s.plugHash);
        if(s.reusablePlugHashes!= null) perkHashes.addAll(s.reusablePlugHashes);
      });
    });

    itemDefinitions = await manifest
        .getDefinitions<DestinyInventoryItemDefinition>(hashes.toList());

    perkDefinitions = await manifest
        .getDefinitions<DestinyInventoryItemDefinition>(perkHashes.toList());

    if (mounted) {
      sortItems();
      setState(() {});
    }
  }

  List<SortParameter> get sortOrder => widget.tabData.sortOrder;

  sortItems() {
    items.sort((itemA, itemB) => InventoryUtils.sortDestinyItems(
        itemA.item, itemB.item, widget.profile,
        defA: itemDefinitions[itemA.item.itemHash],
        defB: itemDefinitions[itemB.item.itemHash],
        sortingParams: sortOrder));
  }

  Widget build(BuildContext context) {
    if(itemDefinitions == null){
      return Center(
        child: Container(
        width: 96,
        child: Shimmer.fromColors(
          baseColor: Colors.blueGrey.shade300,
          highlightColor: Colors.white,
          child: Image.asset("assets/anim/loading.webp"),
        ))
      );
    }
    double screenWidth = MediaQuery.of(context).size.width;
    return StaggeredGridView.countBuilder(
      padding: EdgeInsets.all(4),
      crossAxisCount: screenWidth > 480 ? 12 : 6,
      itemCount: filteredItems?.length ?? 0,
      itemBuilder: (BuildContext context, int index) => getItem(context, index),
      staggeredTileBuilder: (int index) => getTileBuilder(context, index),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      physics: const AlwaysScrollableScrollPhysics(),
    );
  }

  FilterItem get powerLevelFilter =>
      widget.tabData.filterData[FilterType.powerLevel];
  FilterItem get damageTypeFilter =>
      widget.tabData.filterData[FilterType.damageType];
  FilterItem get tierTypeFilter =>
      widget.tabData.filterData[FilterType.tierType];
  FilterItem get bucketTypeFilter =>
      widget.tabData.filterData[FilterType.bucketType];
  FilterItem get subtypeFilter =>
      widget.tabData.filterData[FilterType.itemSubType];
  FilterItem get typeFilter => widget.tabData.filterData[FilterType.itemType];
  FilterItem get ammoTypeFilter =>
      widget.tabData.filterData[FilterType.ammoType];
  FilterItem get classTypeFilter =>
      widget.tabData.filterData[FilterType.classType];

  List<int> get itemTypes => widget.tabData.itemTypes;
  List<int> get excludeItemTypes => widget.tabData.excludeItemTypes;

  List<ItemWithOwner> get filteredItems {
    if (itemDefinitions == null) return [];
    Set<int> perksMatched = new Set();
    if(perkDefinitions == null) return [];
    for(var p in perkDefinitions.values){
     var match = p.displayProperties.name
          .toLowerCase()
          .contains(search.toLowerCase());
      if(match) perksMatched.add(p.hash);
    }

    var _search = removeDiacritics(search).toLowerCase();

    return items.where((item) {
      var def = itemDefinitions[item.item.itemHash];
      if (def == null) return false;
      if (itemTypes != null &&
          !itemTypes.contains(def.itemType)) {
        return false;
      }
      if (excludeItemTypes != null &&
          excludeItemTypes.contains(def.itemType)) {
        return false;
      }
      if (powerLevelFilter != null) {
        var values = powerLevelFilter.values;
        DestinyItemInstanceComponent instance =
            ProfileService().getInstanceInfo(item.item.itemInstanceId);
        int power = instance?.primaryStat?.value;
        if (power != null && (power > values[1])) {
          return false;
        }
      }

      if (damageTypeFilter != null) {
        var values = damageTypeFilter.values;
        DestinyItemInstanceComponent instance =
            ProfileService().getInstanceInfo(item.item.itemInstanceId);
        int damageType = instance?.damageType;

        if (damageType != null &&
            values.length != 0 &&
            !values.contains(damageType)) {
          return false;
        }
      }

      if (tierTypeFilter != null) {
        var values = tierTypeFilter.values;
        var tier = def?.inventory?.tierType;

        if (tier != null && values.length != 0 && !values.contains(tier)) {
          return false;
        }
      }

      if (bucketTypeFilter != null) {
        var values = bucketTypeFilter.values;
        var bucketHash = def?.inventory?.bucketTypeHash;

        if (bucketHash != null &&
            values.length != 0 &&
            !values.contains(bucketHash)) {
          return false;
        }
      }

      if (typeFilter != null) {
        var values = typeFilter.values;
        var type = def?.itemType;
        if (type != null && values.length != 0 && !values.contains(type)) {
          return false;
        }
      }

      if (subtypeFilter != null) {
        var values = subtypeFilter.values;
        var subtype = def?.itemSubType;
        if (subtype != null &&
            values.length != 0 &&
            !values.contains(subtype)) {
          return false;
        }
      }

      if (ammoTypeFilter != null) {
        var values = ammoTypeFilter.values;
        var ammoType = def?.equippingBlock?.ammoType;
        if (ammoType != null &&
            values.length != 0 &&
            !values.contains(ammoType)) {
          return false;
        }
      }

      if (classTypeFilter != null) {
        var values = classTypeFilter.values;
        var classType = def?.classType;
        if (classType != null &&
            values.length != 0 &&
            !values.contains(classType)) {
          return false;
        }
      }

      if (_search.length == 0) {
        return true;
      }
      bool match = false;
      var name = removeDiacritics(def.displayProperties.name).toLowerCase();
      var itemTypeDisplayName = removeDiacritics(def.itemTypeDisplayName).toLowerCase();
      if (_search.length < 4) {
        match = name
          .startsWith(_search);
        match = match || itemTypeDisplayName.startsWith(_search);
      }else{
        match = name
          .contains(_search);
        match = match || itemTypeDisplayName.contains(_search);
      }
      var sockets = widget.profile.getItemSockets(item?.item?.itemInstanceId ?? 0);
      if(sockets != null){
        for(var s in sockets){
          if(s.plugHash != null && perksMatched.contains(s.plugHash)){
            return true;
          }
          if(s.reusablePlugHashes != null){
            for(var p in s.reusablePlugHashes){
              if(perksMatched.contains(p)){
                return true;
              }
            }
          }
        }
      }
      return match;
    }).toList();
  }

  StaggeredTile getTileBuilder(BuildContext context, int index) {
    return StaggeredTile.extent(6, 96);
  }

  Widget getItem(BuildContext context, int index) {
    if(filteredItems == null) return null;
    if(index > filteredItems.length - 1) return null;
    var item = filteredItems[index];
    if (itemDefinitions == null || itemDefinitions[item.item.itemHash] == null)
      return Container();
    return SearchItemWrapperWidget(item.item,
        itemDefinitions[item.item.itemHash]?.inventory?.bucketTypeHash,
        characterId: item.ownerId,
        key: Key("item_${item.item.itemInstanceId}_${item.item.itemHash}"));
  }

  @override
  bool get wantKeepAlive => true;
}
