import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:unn_mobile/core/misc/date_time_extensions.dart';
import 'package:unn_mobile/core/models/schedule_filter.dart';
import 'package:unn_mobile/core/models/subject.dart';
import 'package:unn_mobile/core/viewmodels/base_view_model.dart';
import 'package:unn_mobile/core/viewmodels/schedule_screen_view_model.dart';
import 'package:unn_mobile/ui/views/base_view.dart';
import 'package:unn_mobile/ui/views/main_page/schedule/widgets/schedule_item_normal.dart';
import 'package:unn_mobile/ui/views/main_page/schedule/widgets/schedule_search_suggestion_item.dart';
import 'package:flutter_changed/search_anchor.dart' as flutter_changed;
import 'package:unn_mobile/ui/widgets/persistent_header.dart';

class ScheduleTab extends StatefulWidget {
  final IDType type;

  const ScheduleTab(this.type, {super.key});

  @override
  State<ScheduleTab> createState() => ScheduleTabState();
}

class ScheduleTabState extends State<ScheduleTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = flutter_changed.SearchController();
  final _searchFocusNode = FocusNode();
  final _scrollController = AutoScrollController();
  final _viewKey = GlobalKey();

  bool _searchViewOpen = false;
  String searchQueryForRestore = "";
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!_searchViewOpen && _searchController.isOpen) {
        searchQueryForRestore = _searchController.text;
      }
      _searchViewOpen = _searchController.isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return BaseView<ScheduleScreenViewModel>(
      key: _viewKey,
      builder: (context, model, child) {
        return Column(
          children: [
              _customScrollView(theme, model)
          ],
        );
      },
      onModelReady: (model) {
        model.init(
          widget.type,
          onScheduleLoaded: (schedule) async {
            int todayScheduleIndex = -1;
            for (int i = 0; i < schedule.values.length; i++) {
              if (schedule.values
                  .elementAt(i)[0]
                  .dateTimeRange
                  .start
                  .isSameDate(DateTime.now())) {
                todayScheduleIndex = i;
                break;
              }
            }
            if (model.displayedWeekOffset == 0 && todayScheduleIndex != -1) {
              await _scrollController.scrollToIndex(todayScheduleIndex,
                  preferPosition: AutoScrollPosition.begin);
            } else {
              await _scrollController.scrollToIndex(0,
                  preferPosition: AutoScrollPosition.begin);
            }
          },
        );
      },
    );
  }

  Widget _searchBar(ScheduleScreenViewModel model, BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      child: flutter_changed.SearchAnchor(
        textInputAction: TextInputAction.search,
        viewOnBackButtonClick: (value) {
          _searchController.text = searchQueryForRestore;
          Future.delayed(
            const Duration(milliseconds: 50),
            () {
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            },
          );
        },
        viewOnSubmitted: (value) async {
          var resultingFieldText = searchQueryForRestore;
          if (value == '' && value != model.lastSearchQuery) {
            await model.submitSearch(value);
            resultingFieldText = value;
          }
          _searchController.closeView(resultingFieldText);
          Future.delayed(
            const Duration(milliseconds: 50),
            () {
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            },
          );
        },
        searchController: _searchController,
        isFullScreen: true,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: SearchBar(
                hintText: model.searchPlaceholderText,
                leading: const Icon(Icons.search),
                focusNode: _searchFocusNode,
                trailing: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
                shape: MaterialStateProperty.resolveWith(
                  (states) => const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(10),
                    ),
                  ),
                ),
                onTap: () => controller.openView(),
                onChanged: (_) {
                  controller.openView();
                },
                onSubmitted: (value) async {
                  if (model.lastSearchQuery != value) {
                    await model.submitSearch(value);
                  }
                },
                controller: controller,
              ),
            ),
          );
        },
        suggestionsBuilder: (context, controller) async {
          final rawSuggestions = await model.getSearchSuggestions(
              controller.text); // Неэффективно, но работает >:(
          if (controller.text == '') {
            final suggestions = await model.getHistorySuggestions();
            return suggestions.map((e) => ScheduleSearchSuggestionItem(
                  itemName: e,
                  onSelected: () async {
                    controller.closeView(e);
                    if (model.lastSearchQuery != e) {
                      model.lastSearchQuery = e;
                      await model.addHistoryItem(e);
                      await model.submitSearch(e);
                    }
                  },
                ));
          } else {
            return rawSuggestions.map<ScheduleSearchSuggestionItem>(
              (e) => ScheduleSearchSuggestionItem(
                itemName: e.label,
                itemDescription: e.description,
                onSelected: () {
                  controller.closeView(e.label);
                  Future.delayed(
                    const Duration(milliseconds: 50),
                    () {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                    },
                  );
                  model.lastSearchQuery = controller.text;
                  model.addHistoryItem(e.label);
                  model.selectedId = e.id;
                  model.updateFilter(e.id);
                },
              ),
            );
          }
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _customScrollView(
      ThemeData theme,
      ScheduleScreenViewModel model) {
    final headerFormatter = DateFormat.yMd('ru_RU');

    return Expanded(
      child: FutureBuilder(
        future: model.scheduleLoader,
        builder: (context, snapshot) {
          return CustomScrollView(
            controller: _scrollController,
            cacheExtent: 10,
            slivers: [
              if(!model.offline) SliverPersistentHeader(
                delegate: PersistentHeader(
                  maxExtent: 60,
                  widget: Container(
                    color: theme.colorScheme.background,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 5),
                      child: _searchBar(model, context),
                    ),
                  ),
                ),
                pinned: false,
                floating: true,
              ),
              if(snapshot.connectionState != ConnectionState.none) SliverAppBar(
                leading: model.offline ? null : IconButton(
                  onPressed: () async {
                    await model.decrementWeek();
                  },
                  icon: const Icon(Icons.chevron_left_sharp),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  if(!model.offline) IconButton(
                    onPressed: () async {
                      await model.incrementWeek();
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
                centerTitle: true,
                title: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1,
                  child: Text(
                      '${headerFormatter.format(model.displayedWeek.start)} - ${headerFormatter.format(model.displayedWeek.end)}'),
                ),
                backgroundColor: theme.colorScheme.background,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                toolbarHeight: 50,
                collapsedHeight: 50,
                expandedHeight: 50,
              ),
              if (model.state == ViewState.idle && snapshot.hasData)
                if (snapshot.data!.isNotEmpty)
                  _scheduleSliverList(model, snapshot, theme)
                else
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "На этой неделе занятий нет :)",
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  )
              else if(snapshot.connectionState != ConnectionState.none)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
            ],
          ); 
        }
      ),
    );
  }

  SliverList _scheduleSliverList(ScheduleScreenViewModel model,
      AsyncSnapshot<Map<int, List<Subject>>> snapshot, ThemeData theme) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          var formatedDate = toBeginningOfSentenceCase(DateFormat.MMMMEEEEd('ru_RU').format(
            model.displayedWeek.start.add(
              Duration(days: snapshot.data!.keys.elementAt(index) - 1),
            ),
          ));

          return AutoScrollTag(
            key: ValueKey(index),
            controller: _scrollController,
            index: index,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    decoration: (snapshot.data!.values
                            .elementAt(index)
                            .first
                            .dateTimeRange
                            .start
                            .isSameDate(DateTime.now()))
                        ? BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: theme.primaryColor)))
                        : null,
                    child: Text(
                      formatedDate!,
                      textAlign: TextAlign.left,
                      style: theme.textTheme.titleLarge!.copyWith(),
                    ),
                  ),
                ),
                for (int i = 0;
                    i < snapshot.data!.values.elementAt(index).length;
                    i++)
                  ScheduleItemNormal(
                      subject: snapshot.data!.values.elementAt(index)[i],
                      even: i % 2 == 0),
              ],
            ),
          );
        },
        childCount: snapshot.data!.length,
      ),
    );
  }

  void refreshTab() {
    final model =
        (_viewKey.currentState as BaseViewState<ScheduleScreenViewModel>).model;
    if (model.displayedWeekOffset != 0) {
      model.resetWeek();
    }
  }
}
