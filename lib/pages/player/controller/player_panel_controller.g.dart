// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_panel_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$PlayerPanelController on _PlayerPanelController, Store {
  late final _$aspectRatioModeAtom = Atom(
    name: '_PlayerPanelController.aspectRatioMode',
    context: context,
  );

  @override
  PlayerAspectRatio get aspectRatioMode {
    _$aspectRatioModeAtom.reportRead();
    return super.aspectRatioMode;
  }

  @override
  set aspectRatioMode(PlayerAspectRatio value) {
    _$aspectRatioModeAtom.reportWrite(value, super.aspectRatioMode, () {
      super.aspectRatioMode = value;
    });
  }

  late final _$lockPanelAtom = Atom(
    name: '_PlayerPanelController.lockPanel',
    context: context,
  );

  @override
  bool get lockPanel {
    _$lockPanelAtom.reportRead();
    return super.lockPanel;
  }

  @override
  set lockPanel(bool value) {
    _$lockPanelAtom.reportWrite(value, super.lockPanel, () {
      super.lockPanel = value;
    });
  }

  late final _$showVideoControllerAtom = Atom(
    name: '_PlayerPanelController.showVideoController',
    context: context,
  );

  @override
  bool get showVideoController {
    _$showVideoControllerAtom.reportRead();
    return super.showVideoController;
  }

  @override
  set showVideoController(bool value) {
    _$showVideoControllerAtom.reportWrite(value, super.showVideoController, () {
      super.showVideoController = value;
    });
  }

  late final _$showSeekTimeAtom = Atom(
    name: '_PlayerPanelController.showSeekTime',
    context: context,
  );

  @override
  bool get showSeekTime {
    _$showSeekTimeAtom.reportRead();
    return super.showSeekTime;
  }

  @override
  set showSeekTime(bool value) {
    _$showSeekTimeAtom.reportWrite(value, super.showSeekTime, () {
      super.showSeekTime = value;
    });
  }

  late final _$seekCancelPendingAtom = Atom(
    name: '_PlayerPanelController.seekCancelPending',
    context: context,
  );

  @override
  bool get seekCancelPending {
    _$seekCancelPendingAtom.reportRead();
    return super.seekCancelPending;
  }

  @override
  set seekCancelPending(bool value) {
    _$seekCancelPendingAtom.reportWrite(value, super.seekCancelPending, () {
      super.seekCancelPending = value;
    });
  }

  late final _$showPlaySpeedAtom = Atom(
    name: '_PlayerPanelController.showPlaySpeed',
    context: context,
  );

  @override
  bool get showPlaySpeed {
    _$showPlaySpeedAtom.reportRead();
    return super.showPlaySpeed;
  }

  @override
  set showPlaySpeed(bool value) {
    _$showPlaySpeedAtom.reportWrite(value, super.showPlaySpeed, () {
      super.showPlaySpeed = value;
    });
  }

  late final _$canHidePlayerPanelAtom = Atom(
    name: '_PlayerPanelController.canHidePlayerPanel',
    context: context,
  );

  @override
  bool get canHidePlayerPanel {
    _$canHidePlayerPanelAtom.reportRead();
    return super.canHidePlayerPanel;
  }

  @override
  set canHidePlayerPanel(bool value) {
    _$canHidePlayerPanelAtom.reportWrite(value, super.canHidePlayerPanel, () {
      super.canHidePlayerPanel = value;
    });
  }

  late final _$_PlayerPanelControllerActionController = ActionController(
    name: '_PlayerPanelController',
    context: context,
  );

  @override
  void reset() {
    final _$actionInfo = _$_PlayerPanelControllerActionController.startAction(
      name: '_PlayerPanelController.reset',
    );
    try {
      return super.reset();
    } finally {
      _$_PlayerPanelControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
aspectRatioMode: ${aspectRatioMode},
lockPanel: ${lockPanel},
showVideoController: ${showVideoController},
showSeekTime: ${showSeekTime},
seekCancelPending: ${seekCancelPending},
showPlaySpeed: ${showPlaySpeed},
canHidePlayerPanel: ${canHidePlayerPanel}
    ''';
  }
}
