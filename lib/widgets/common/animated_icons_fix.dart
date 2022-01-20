// TODO TLAD [rtl] remove the whole file when this is fixed: https://github.com/flutter/flutter/issues/60521
// as of Flutter v2.8.1, mirrored animated icon is misplaced
// cf PR https://github.com/flutter/flutter/pull/93312

// ignore_for_file: constant_identifier_names, curly_braces_in_flow_control_structures, unnecessary_null_comparison
import 'dart:math' as math show pi;
import 'dart:ui' as ui show Paint, Path, Canvas;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

abstract class AnimatedIconData {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const AnimatedIconData();

  /// Whether this icon should be mirrored horizontally when text direction is
  /// right-to-left.
  ///
  /// See also:
  ///
  ///  * [TextDirection], which discusses concerns regarding reading direction
  ///    in Flutter.
  ///  * [Directionality], a widget which determines the ambient directionality.
  bool get matchTextDirection;
}

class _AnimatedIconData extends AnimatedIconData {
  const _AnimatedIconData(this.size, this.paths, {this.matchTextDirection = false});

  final Size size;
  final List<_PathFrames> paths;

  @override
  final bool matchTextDirection;
}

class AnimatedIconFixIssue60521 extends StatelessWidget {
  /// Creates an AnimatedIcon.
  ///
  /// The [progress] and [icon] arguments must not be null.
  /// The [size] and [color] default to the value given by the current [IconTheme].
  const AnimatedIconFixIssue60521({
    Key? key,
    required this.icon,
    required this.progress,
    this.color,
    this.size,
    this.semanticLabel,
    this.textDirection,
  })  : assert(progress != null),
        assert(icon != null),
        super(key: key);

  /// The animation progress for the animated icon.
  ///
  /// The value is clamped to be between 0 and 1.
  ///
  /// This determines the actual frame that is displayed.
  final Animation<double> progress;

  /// The color to use when drawing the icon.
  ///
  /// Defaults to the current [IconTheme] color, if any.
  ///
  /// The given color will be adjusted by the opacity of the current
  /// [IconTheme], if any.
  ///
  /// In material apps, if there is a [Theme] without any [IconTheme]s
  /// specified, icon colors default to white if the theme is dark
  /// and black if the theme is light.
  ///
  /// If no [IconTheme] and no [Theme] is specified, icons will default to black.
  ///
  /// See [Theme] to set the current theme and [ThemeData.brightness]
  /// for setting the current theme's brightness.
  final Color? color;

  /// The size of the icon in logical pixels.
  ///
  /// Icons occupy a square with width and height equal to size.
  ///
  /// Defaults to the current [IconTheme] size.
  final double? size;

  /// The icon to display. Available icons are listed in [AnimatedIcons].
  final AnimatedIconData icon;

  /// Semantic label for the icon.
  ///
  /// Announced in accessibility modes (e.g TalkBack/VoiceOver).
  /// This label does not show in the UI.
  ///
  /// See also:
  ///
  ///  * [SemanticsProperties.label], which is set to [semanticLabel] in the
  ///    underlying [Semantics] widget.
  final String? semanticLabel;

  /// The text direction to use for rendering the icon.
  ///
  /// If this is null, the ambient [Directionality] is used instead.
  ///
  /// If the text direction is [TextDirection.rtl], the icon will be mirrored
  /// horizontally (e.g back arrow will point right).
  final TextDirection? textDirection;

  static ui.Path _pathFactory() => ui.Path();

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final _AnimatedIconData iconData = icon as _AnimatedIconData;
    final IconThemeData iconTheme = IconTheme.of(context);
    assert(iconTheme.isConcrete);
    final double iconSize = size ?? iconTheme.size!;
    final TextDirection textDirection = this.textDirection ?? Directionality.of(context);
    final double iconOpacity = iconTheme.opacity!;
    Color iconColor = color ?? iconTheme.color!;
    if (iconOpacity != 1.0) iconColor = iconColor.withOpacity(iconColor.opacity * iconOpacity);
    return Semantics(
      label: semanticLabel,
      child: CustomPaint(
        size: Size(iconSize, iconSize),
        painter: _AnimatedIconPainter(
          paths: iconData.paths,
          progress: progress,
          color: iconColor,
          scale: iconSize / iconData.size.width,
          shouldMirror: textDirection == TextDirection.rtl && iconData.matchTextDirection,
          uiPathFactory: _pathFactory,
        ),
      ),
    );
  }
}

typedef _UiPathFactory = ui.Path Function();

class _AnimatedIconPainter extends CustomPainter {
  _AnimatedIconPainter({
    required this.paths,
    required this.progress,
    required this.color,
    required this.scale,
    required this.shouldMirror,
    required this.uiPathFactory,
  }) : super(repaint: progress);

  // This list is assumed to be immutable, changes to the contents of the list
  // will not trigger a redraw as shouldRepaint will keep returning false.
  final List<_PathFrames> paths;
  final Animation<double> progress;
  final Color color;
  final double scale;

  /// If this is true the image will be mirrored horizontally.
  final bool shouldMirror;
  final _UiPathFactory uiPathFactory;

  @override
  void paint(ui.Canvas canvas, Size size) {
    // The RenderCustomPaint render object performs canvas.save before invoking
    // this and canvas.restore after, so we don't need to do it here.
    if (shouldMirror) {
      canvas.rotate(math.pi);
      canvas.translate(-size.width, -size.height);
    }
    canvas.scale(scale, scale);

    final double clampedProgress = progress.value.clamp(0.0, 1.0);
    for (final _PathFrames path in paths) path.paint(canvas, color, uiPathFactory, clampedProgress);
  }

  @override
  bool shouldRepaint(_AnimatedIconPainter oldDelegate) {
    return oldDelegate.progress.value != progress.value ||
        oldDelegate.color != color
        // We are comparing the paths list by reference, assuming the list is
        // treated as immutable to be more efficient.
        ||
        oldDelegate.paths != paths ||
        oldDelegate.scale != scale ||
        oldDelegate.uiPathFactory != uiPathFactory;
  }

  @override
  bool? hitTest(Offset position) => null;

  @override
  bool shouldRebuildSemantics(CustomPainter oldDelegate) => false;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;
}

class _PathFrames {
  const _PathFrames({
    required this.commands,
    required this.opacities,
  });

  final List<_PathCommand> commands;
  final List<double> opacities;

  void paint(ui.Canvas canvas, Color color, _UiPathFactory uiPathFactory, double progress) {
    final double opacity = _interpolate<double?>(opacities, progress, lerpDouble)!;
    final ui.Paint paint = ui.Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(color.opacity * opacity);
    final ui.Path path = uiPathFactory();
    for (final _PathCommand command in commands) command.apply(path, progress);
    canvas.drawPath(path, paint);
  }
}

abstract class _PathCommand {
  const _PathCommand();

  /// Applies the path command to [path].
  ///
  /// For example if the object is a [_PathMoveTo] command it will invoke
  /// [Path.moveTo] on [path].
  void apply(ui.Path path, double progress);
}

class _PathMoveTo extends _PathCommand {
  const _PathMoveTo(this.points);

  final List<Offset> points;

  @override
  void apply(Path path, double progress) {
    final Offset offset = _interpolate<Offset?>(points, progress, Offset.lerp)!;
    path.moveTo(offset.dx, offset.dy);
  }
}

class _PathCubicTo extends _PathCommand {
  const _PathCubicTo(this.controlPoints1, this.controlPoints2, this.targetPoints);

  final List<Offset> controlPoints2;
  final List<Offset> controlPoints1;
  final List<Offset> targetPoints;

  @override
  void apply(Path path, double progress) {
    final Offset controlPoint1 = _interpolate<Offset?>(controlPoints1, progress, Offset.lerp)!;
    final Offset controlPoint2 = _interpolate<Offset?>(controlPoints2, progress, Offset.lerp)!;
    final Offset targetPoint = _interpolate<Offset?>(targetPoints, progress, Offset.lerp)!;
    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      targetPoint.dx,
      targetPoint.dy,
    );
  }
}

// ignore: unused_element
class _PathLineTo extends _PathCommand {
  const _PathLineTo(this.points);

  final List<Offset> points;

  @override
  void apply(Path path, double progress) {
    final Offset point = _interpolate<Offset?>(points, progress, Offset.lerp)!;
    path.lineTo(point.dx, point.dy);
  }
}

class _PathClose extends _PathCommand {
  const _PathClose();

  @override
  void apply(Path path, double progress) {
    path.close();
  }
}

T _interpolate<T>(List<T> values, double progress, _Interpolator<T> interpolator) {
  assert(progress <= 1.0);
  assert(progress >= 0.0);
  if (values.length == 1) return values[0];
  final double targetIdx = lerpDouble(0, values.length - 1, progress)!;
  final int lowIdx = targetIdx.floor();
  final int highIdx = targetIdx.ceil();
  final double t = targetIdx - lowIdx;
  return interpolator(values[lowIdx], values[highIdx], t);
}

typedef _Interpolator<T> = T Function(T a, T b, double progress);

abstract class AnimatedIconsFixIssue60521 {
  static const AnimatedIconData menu_arrow = _AnimatedIconData(
    Size(48.0, 48.0),
    <_PathFrames>[
      _PathFrames(
        opacities: <double>[
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
        ],
        commands: <_PathCommand>[
          _PathMoveTo(
            <Offset>[
              Offset(6.0, 26.0),
              Offset(5.976562557689849, 25.638185989482512),
              Offset(5.951781669661045, 24.367972149512962),
              Offset(6.172793116155802, 21.823631861702058),
              Offset(7.363587976838016, 17.665129222832853),
              Offset(11.400806749308899, 11.800457098273661),
              Offset(17.41878573585796, 8.03287301910486),
              Offset(24.257523532175192, 6.996159828679087),
              Offset(29.90338248135665, 8.291042849526),
              Offset(33.76252909490214, 10.56619705548221),
              Offset(36.23501636298456, 12.973675163618006),
              Offset(37.77053540180521, 15.158665125787222),
              Offset(38.70420448893307, 17.008159945496722),
              Offset(39.260392038988186, 18.5104805430827),
              Offset(39.58393261852967, 19.691668944482075),
              Offset(39.766765502294305, 20.58840471665747),
              Offset(39.866421084642994, 21.237322746452932),
              Offset(39.91802804639694, 21.671102155152063),
              Offset(39.94204075298555, 21.917555098992118),
              Offset(39.94920417650143, 21.999827480806236),
              Offset(39.94921875, 22.0),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(6.0, 26.0),
              Offset(5.976562557689849, 25.638185989482512),
              Offset(5.951781669661045, 24.367972149512962),
              Offset(6.172793116155802, 21.823631861702058),
              Offset(7.363587976838016, 17.665129222832853),
              Offset(11.400806749308899, 11.800457098273661),
              Offset(17.41878573585796, 8.03287301910486),
              Offset(24.257523532175192, 6.996159828679087),
              Offset(29.90338248135665, 8.291042849526),
              Offset(33.76252909490214, 10.56619705548221),
              Offset(36.23501636298456, 12.973675163618006),
              Offset(37.77053540180521, 15.158665125787222),
              Offset(38.70420448893307, 17.008159945496722),
              Offset(39.260392038988186, 18.5104805430827),
              Offset(39.58393261852967, 19.691668944482075),
              Offset(39.766765502294305, 20.58840471665747),
              Offset(39.866421084642994, 21.237322746452932),
              Offset(39.91802804639694, 21.671102155152063),
              Offset(39.94204075298555, 21.917555098992118),
              Offset(39.94920417650143, 21.999827480806236),
              Offset(39.94921875, 22.0),
            ],
            <Offset>[
              Offset(42.0, 26.0),
              Offset(41.91421333157091, 26.360426629492423),
              Offset(41.55655262500356, 27.60382930516768),
              Offset(40.57766190556539, 29.99090297157744),
              Offset(38.19401046368096, 33.57567286235671),
              Offset(32.70215654116029, 37.756226919427284),
              Offset(26.22621984436523, 39.26167875408963),
              Offset(20.102351173097617, 38.04803275423973),
              Offset(15.903199608216863, 35.25316524725598),
              Offset(13.57741782841064, 32.27000071222682),
              Offset(12.442030802775209, 29.665215617986277),
              Offset(11.981806515947115, 27.560177578292762),
              Offset(11.879421136842055, 25.918712565594948),
              Offset(11.95091483982305, 24.66543021784112),
              Offset(12.092167805674123, 23.72603017548901),
              Offset(12.245452640806768, 23.03857447590349),
              Offset(12.379956070248545, 22.554583229506296),
              Offset(12.480582865035407, 22.237279988168645),
              Offset(12.541514124262473, 22.059212079933666),
              Offset(12.562455771803593, 22.000123717314214),
              Offset(12.562499999999996, 22.000000000000004),
            ],
            <Offset>[
              Offset(42.0, 26.0),
              Offset(41.91421333157091, 26.360426629492423),
              Offset(41.55655262500356, 27.60382930516768),
              Offset(40.57766190556539, 29.99090297157744),
              Offset(38.19401046368096, 33.57567286235671),
              Offset(32.70215654116029, 37.756226919427284),
              Offset(26.22621984436523, 39.26167875408963),
              Offset(20.102351173097617, 38.04803275423973),
              Offset(15.903199608216863, 35.25316524725598),
              Offset(13.57741782841064, 32.27000071222682),
              Offset(12.442030802775209, 29.665215617986277),
              Offset(11.981806515947115, 27.560177578292762),
              Offset(11.879421136842055, 25.918712565594948),
              Offset(11.95091483982305, 24.66543021784112),
              Offset(12.092167805674123, 23.72603017548901),
              Offset(12.245452640806768, 23.03857447590349),
              Offset(12.379956070248545, 22.554583229506296),
              Offset(12.480582865035407, 22.237279988168645),
              Offset(12.541514124262473, 22.059212079933666),
              Offset(12.562455771803593, 22.000123717314214),
              Offset(12.562499999999996, 22.000000000000004),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(42.0, 26.0),
              Offset(41.91421333157091, 26.360426629492423),
              Offset(41.55655262500356, 27.60382930516768),
              Offset(40.57766190556539, 29.99090297157744),
              Offset(38.19401046368096, 33.57567286235671),
              Offset(32.70215654116029, 37.756226919427284),
              Offset(26.22621984436523, 39.26167875408963),
              Offset(20.102351173097617, 38.04803275423973),
              Offset(15.903199608216863, 35.25316524725598),
              Offset(13.57741782841064, 32.27000071222682),
              Offset(12.442030802775209, 29.665215617986277),
              Offset(11.981806515947115, 27.560177578292762),
              Offset(11.879421136842055, 25.918712565594948),
              Offset(11.95091483982305, 24.66543021784112),
              Offset(12.092167805674123, 23.72603017548901),
              Offset(12.245452640806768, 23.03857447590349),
              Offset(12.379956070248545, 22.554583229506296),
              Offset(12.480582865035407, 22.237279988168645),
              Offset(12.541514124262473, 22.059212079933666),
              Offset(12.562455771803593, 22.000123717314214),
              Offset(12.562499999999996, 22.000000000000004),
            ],
            <Offset>[
              Offset(42.0, 22.0),
              Offset(41.99458528858859, 22.361234167441474),
              Offset(41.91859127809106, 23.620246996030513),
              Offset(41.501535596836376, 26.09905798461081),
              Offset(40.02840620381446, 30.021099432452637),
              Offset(35.79419835461124, 35.2186537827727),
              Offset(30.076040790179817, 38.175916954629336),
              Offset(24.067012730992623, 38.57855959743385),
              Offset(19.453150566288006, 37.096490556388844),
              Offset(16.506465839286186, 34.99409280868502),
              Offset(14.73924581501028, 32.939784778587686),
              Offset(13.715334530064114, 31.165018854170466),
              Offset(13.140377980959201, 29.714761542791386),
              Offset(12.83036672005031, 28.56755327976071),
              Offset(12.672939622830032, 27.683643609921106),
              Offset(12.600162038813565, 27.02281609043513),
              Offset(12.571432188039635, 26.54999771317575),
              Offset(12.56310619400641, 26.23642863509033),
              Offset(12.562193301685781, 26.059158626029138),
              Offset(12.562499038934627, 26.000123717080207),
              Offset(12.562499999999996, 26.000000000000004),
            ],
            <Offset>[
              Offset(42.0, 22.0),
              Offset(41.99458528858859, 22.361234167441474),
              Offset(41.91859127809106, 23.620246996030513),
              Offset(41.501535596836376, 26.09905798461081),
              Offset(40.02840620381446, 30.021099432452637),
              Offset(35.79419835461124, 35.2186537827727),
              Offset(30.076040790179817, 38.175916954629336),
              Offset(24.067012730992623, 38.57855959743385),
              Offset(19.453150566288006, 37.096490556388844),
              Offset(16.506465839286186, 34.99409280868502),
              Offset(14.73924581501028, 32.939784778587686),
              Offset(13.715334530064114, 31.165018854170466),
              Offset(13.140377980959201, 29.714761542791386),
              Offset(12.83036672005031, 28.56755327976071),
              Offset(12.672939622830032, 27.683643609921106),
              Offset(12.600162038813565, 27.02281609043513),
              Offset(12.571432188039635, 26.54999771317575),
              Offset(12.56310619400641, 26.23642863509033),
              Offset(12.562193301685781, 26.059158626029138),
              Offset(12.562499038934627, 26.000123717080207),
              Offset(12.562499999999996, 26.000000000000004),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(42.0, 22.0),
              Offset(41.99458528858859, 22.361234167441474),
              Offset(41.91859127809106, 23.620246996030513),
              Offset(41.501535596836376, 26.09905798461081),
              Offset(40.02840620381446, 30.021099432452637),
              Offset(35.79419835461124, 35.2186537827727),
              Offset(30.076040790179817, 38.175916954629336),
              Offset(24.067012730992623, 38.57855959743385),
              Offset(19.453150566288006, 37.096490556388844),
              Offset(16.506465839286186, 34.99409280868502),
              Offset(14.73924581501028, 32.939784778587686),
              Offset(13.715334530064114, 31.165018854170466),
              Offset(13.140377980959201, 29.714761542791386),
              Offset(12.83036672005031, 28.56755327976071),
              Offset(12.672939622830032, 27.683643609921106),
              Offset(12.600162038813565, 27.02281609043513),
              Offset(12.571432188039635, 26.54999771317575),
              Offset(12.56310619400641, 26.23642863509033),
              Offset(12.562193301685781, 26.059158626029138),
              Offset(12.562499038934627, 26.000123717080207),
              Offset(12.562499999999996, 26.000000000000004),
            ],
            <Offset>[
              Offset(6.0, 22.0),
              Offset(6.056934514707525, 21.63899352743156),
              Offset(6.3138203227485405, 20.384389840375796),
              Offset(7.096666807426793, 17.931786874735423),
              Offset(9.197983716971518, 14.110555792928775),
              Offset(14.492848562759846, 9.262883961619078),
              Offset(21.26860668167255, 6.947111219644562),
              Offset(28.222185090070198, 7.526686671873211),
              Offset(33.453333439427794, 10.134368158658866),
              Offset(36.69157710577769, 13.290289151940406),
              Offset(38.53223137521963, 16.248244324219414),
              Offset(39.50406341592221, 18.763506401664923),
              Offset(39.965161333050226, 20.80420892269316),
              Offset(40.139843919215444, 22.41260360500229),
              Offset(40.164704435685586, 23.649282378914172),
              Offset(40.1214749003011, 24.572646331189105),
              Offset(40.057897202434084, 25.232737230122385),
              Offset(40.00055137536795, 25.670250802073745),
              Offset(39.96271993040885, 25.917501645087587),
              Offset(39.949247443632466, 25.99982748057223),
              Offset(39.94921875, 26.0),
            ],
            <Offset>[
              Offset(6.0, 22.0),
              Offset(6.056934514707525, 21.63899352743156),
              Offset(6.3138203227485405, 20.384389840375796),
              Offset(7.096666807426793, 17.931786874735423),
              Offset(9.197983716971518, 14.110555792928775),
              Offset(14.492848562759846, 9.262883961619078),
              Offset(21.26860668167255, 6.947111219644562),
              Offset(28.222185090070198, 7.526686671873211),
              Offset(33.453333439427794, 10.134368158658866),
              Offset(36.69157710577769, 13.290289151940406),
              Offset(38.53223137521963, 16.248244324219414),
              Offset(39.50406341592221, 18.763506401664923),
              Offset(39.965161333050226, 20.80420892269316),
              Offset(40.139843919215444, 22.41260360500229),
              Offset(40.164704435685586, 23.649282378914172),
              Offset(40.1214749003011, 24.572646331189105),
              Offset(40.057897202434084, 25.232737230122385),
              Offset(40.00055137536795, 25.670250802073745),
              Offset(39.96271993040885, 25.917501645087587),
              Offset(39.949247443632466, 25.99982748057223),
              Offset(39.94921875, 26.0),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(6.0, 22.0),
              Offset(6.056934514707525, 21.63899352743156),
              Offset(6.3138203227485405, 20.384389840375796),
              Offset(7.096666807426793, 17.931786874735423),
              Offset(9.197983716971518, 14.110555792928775),
              Offset(14.492848562759846, 9.262883961619078),
              Offset(21.26860668167255, 6.947111219644562),
              Offset(28.222185090070198, 7.526686671873211),
              Offset(33.453333439427794, 10.134368158658866),
              Offset(36.69157710577769, 13.290289151940406),
              Offset(38.53223137521963, 16.248244324219414),
              Offset(39.50406341592221, 18.763506401664923),
              Offset(39.965161333050226, 20.80420892269316),
              Offset(40.139843919215444, 22.41260360500229),
              Offset(40.164704435685586, 23.649282378914172),
              Offset(40.1214749003011, 24.572646331189105),
              Offset(40.057897202434084, 25.232737230122385),
              Offset(40.00055137536795, 25.670250802073745),
              Offset(39.96271993040885, 25.917501645087587),
              Offset(39.949247443632466, 25.99982748057223),
              Offset(39.94921875, 26.0),
            ],
            <Offset>[
              Offset(6.0, 26.0),
              Offset(5.976562557689849, 25.638185989482512),
              Offset(5.951781669661045, 24.367972149512962),
              Offset(6.172793116155802, 21.823631861702058),
              Offset(7.363587976838016, 17.665129222832853),
              Offset(11.400806749308899, 11.800457098273661),
              Offset(17.41878573585796, 8.03287301910486),
              Offset(24.257523532175192, 6.996159828679087),
              Offset(29.90338248135665, 8.291042849526),
              Offset(33.76252909490214, 10.56619705548221),
              Offset(36.23501636298456, 12.973675163618006),
              Offset(37.77053540180521, 15.158665125787222),
              Offset(38.70420448893307, 17.008159945496722),
              Offset(39.260392038988186, 18.5104805430827),
              Offset(39.58393261852967, 19.691668944482075),
              Offset(39.766765502294305, 20.58840471665747),
              Offset(39.866421084642994, 21.237322746452932),
              Offset(39.91802804639694, 21.671102155152063),
              Offset(39.94204075298555, 21.917555098992118),
              Offset(39.94920417650143, 21.999827480806236),
              Offset(39.94921875, 22.0),
            ],
            <Offset>[
              Offset(6.0, 26.0),
              Offset(5.976562557689849, 25.638185989482512),
              Offset(5.951781669661045, 24.367972149512962),
              Offset(6.172793116155802, 21.823631861702058),
              Offset(7.363587976838016, 17.665129222832853),
              Offset(11.400806749308899, 11.800457098273661),
              Offset(17.41878573585796, 8.03287301910486),
              Offset(24.257523532175192, 6.996159828679087),
              Offset(29.90338248135665, 8.291042849526),
              Offset(33.76252909490214, 10.56619705548221),
              Offset(36.23501636298456, 12.973675163618006),
              Offset(37.77053540180521, 15.158665125787222),
              Offset(38.70420448893307, 17.008159945496722),
              Offset(39.260392038988186, 18.5104805430827),
              Offset(39.58393261852967, 19.691668944482075),
              Offset(39.766765502294305, 20.58840471665747),
              Offset(39.866421084642994, 21.237322746452932),
              Offset(39.91802804639694, 21.671102155152063),
              Offset(39.94204075298555, 21.917555098992118),
              Offset(39.94920417650143, 21.999827480806236),
              Offset(39.94921875, 22.0),
            ],
          ),
          _PathClose(),
        ],
      ),
      _PathFrames(
        opacities: <double>[
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
        ],
        commands: <_PathCommand>[
          _PathMoveTo(
            <Offset>[
              Offset(6.0, 36.0),
              Offset(5.8396336833594695, 35.66398057820908),
              Offset(5.329309336374063, 34.47365089829387),
              Offset(4.546341863759643, 32.03857491308836),
              Offset(3.9472816617934896, 27.893335303194206),
              Offset(4.788314785722232, 21.470485758169694),
              Offset(7.406922551234356, 16.186721598040453),
              Offset(10.987511722222681, 12.449414121983239),
              Offset(14.290737577882037, 10.382465570533384),
              Offset(16.84152025666389, 9.340052761292668),
              Offset(18.753361861843203, 8.79207829497377),
              Offset(20.19495897321279, 8.483469022255434),
              Offset(21.293826339887335, 8.297708512391797),
              Offset(22.135385178177998, 8.180000583359465),
              Offset(22.776244370552647, 8.102975309903787),
              Offset(23.25488929254563, 8.051973096906334),
              Offset(23.598629725699347, 8.018606137477462),
              Offset(23.827700643867974, 7.99783596371886),
              Offset(23.95771797811348, 7.986559676107813),
              Offset(24.001111438945117, 7.982878122631195),
              Offset(24.001202429357242, 7.98287044589657),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(6.0, 36.0),
              Offset(5.8396336833594695, 35.66398057820908),
              Offset(5.329309336374063, 34.47365089829387),
              Offset(4.546341863759643, 32.03857491308836),
              Offset(3.9472816617934896, 27.893335303194206),
              Offset(4.788314785722232, 21.470485758169694),
              Offset(7.406922551234356, 16.186721598040453),
              Offset(10.987511722222681, 12.449414121983239),
              Offset(14.290737577882037, 10.382465570533384),
              Offset(16.84152025666389, 9.340052761292668),
              Offset(18.753361861843203, 8.79207829497377),
              Offset(20.19495897321279, 8.483469022255434),
              Offset(21.293826339887335, 8.297708512391797),
              Offset(22.135385178177998, 8.180000583359465),
              Offset(22.776244370552647, 8.102975309903787),
              Offset(23.25488929254563, 8.051973096906334),
              Offset(23.598629725699347, 8.018606137477462),
              Offset(23.827700643867974, 7.99783596371886),
              Offset(23.95771797811348, 7.986559676107813),
              Offset(24.001111438945117, 7.982878122631195),
              Offset(24.001202429357242, 7.98287044589657),
            ],
            <Offset>[
              Offset(42.0, 36.0),
              Offset(41.7493389152824, 36.20520796529164),
              Offset(40.85819701033384, 36.89246335931071),
              Offset(39.01294315759756, 38.1256246432051),
              Offset(35.758514239960064, 39.76970128020763),
              Offset(30.180134511403956, 41.28645636464381),
              Offset(24.56603417073137, 41.32925393403815),
              Offset(19.271926095830622, 39.91690773672663),
              Offset(15.201959304751512, 37.5726832793895),
              Offset(12.456295622648877, 35.01429311055303),
              Offset(10.686459838185314, 32.608514843335385),
              Offset(9.579921816288039, 30.502293804851334),
              Offset(8.90802993167501, 28.734147272525124),
              Offset(8.513791284564158, 27.294928344333726),
              Offset(8.292240475325507, 26.156988797411067),
              Offset(8.174465865426919, 25.287693028463128),
              Offset(8.11616441641861, 24.655137447505503),
              Offset(8.089821190085125, 24.230473791307258),
              Offset(8.079382709319852, 23.988506993748523),
              Offset(8.076631388780909, 23.907616552409003),
              Offset(8.076626005900048, 23.907446869353766),
            ],
            <Offset>[
              Offset(42.0, 36.0),
              Offset(41.7493389152824, 36.20520796529164),
              Offset(40.85819701033384, 36.89246335931071),
              Offset(39.01294315759756, 38.1256246432051),
              Offset(35.758514239960064, 39.76970128020763),
              Offset(30.180134511403956, 41.28645636464381),
              Offset(24.56603417073137, 41.32925393403815),
              Offset(19.271926095830622, 39.91690773672663),
              Offset(15.201959304751512, 37.5726832793895),
              Offset(12.456295622648877, 35.01429311055303),
              Offset(10.686459838185314, 32.608514843335385),
              Offset(9.579921816288039, 30.502293804851334),
              Offset(8.90802993167501, 28.734147272525124),
              Offset(8.513791284564158, 27.294928344333726),
              Offset(8.292240475325507, 26.156988797411067),
              Offset(8.174465865426919, 25.287693028463128),
              Offset(8.11616441641861, 24.655137447505503),
              Offset(8.089821190085125, 24.230473791307258),
              Offset(8.079382709319852, 23.988506993748523),
              Offset(8.076631388780909, 23.907616552409003),
              Offset(8.076626005900048, 23.907446869353766),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(42.0, 36.0),
              Offset(41.7493389152824, 36.20520796529164),
              Offset(40.85819701033384, 36.89246335931071),
              Offset(39.01294315759756, 38.1256246432051),
              Offset(35.758514239960064, 39.76970128020763),
              Offset(30.180134511403956, 41.28645636464381),
              Offset(24.56603417073137, 41.32925393403815),
              Offset(19.271926095830622, 39.91690773672663),
              Offset(15.201959304751512, 37.5726832793895),
              Offset(12.456295622648877, 35.01429311055303),
              Offset(10.686459838185314, 32.608514843335385),
              Offset(9.579921816288039, 30.502293804851334),
              Offset(8.90802993167501, 28.734147272525124),
              Offset(8.513791284564158, 27.294928344333726),
              Offset(8.292240475325507, 26.156988797411067),
              Offset(8.174465865426919, 25.287693028463128),
              Offset(8.11616441641861, 24.655137447505503),
              Offset(8.089821190085125, 24.230473791307258),
              Offset(8.079382709319852, 23.988506993748523),
              Offset(8.076631388780909, 23.907616552409003),
              Offset(8.076626005900048, 23.907446869353766),
            ],
            <Offset>[
              Offset(42.0, 32.0),
              Offset(41.803966700752746, 32.205577011286266),
              Offset(41.104447603276626, 32.89996903899956),
              Offset(39.64402995767152, 34.17517788052204),
              Offset(37.031973302731046, 35.97545970343111),
              Offset(32.44508133022271, 37.98012671725157),
              Offset(27.6644042246058, 38.77327245743646),
              Offset(22.963108117227325, 38.302914175295534),
              Offset(19.18039906547299, 36.862333955479784),
              Offset(16.509090720567585, 35.04434211490934),
              Offset(14.703380298498667, 33.21759365821649),
              Offset(13.512146444284534, 31.556733263561572),
              Offset(12.740174664860898, 30.12862517729895),
              Offset(12.248059307884624, 28.947244716051806),
              Offset(11.939734974297815, 28.002595790430043),
              Offset(11.750425410476474, 27.27521551305395),
              Offset(11.637314290474384, 26.742992599694542),
              Offset(11.572897732210654, 26.384358993735816),
              Offset(11.54031155133882, 26.17955109507089),
              Offset(11.530083003283234, 26.111009046369567),
              Offset(11.530061897030713, 26.110865227715482),
            ],
            <Offset>[
              Offset(42.0, 32.0),
              Offset(41.803966700752746, 32.205577011286266),
              Offset(41.104447603276626, 32.89996903899956),
              Offset(39.64402995767152, 34.17517788052204),
              Offset(37.031973302731046, 35.97545970343111),
              Offset(32.44508133022271, 37.98012671725157),
              Offset(27.6644042246058, 38.77327245743646),
              Offset(22.963108117227325, 38.302914175295534),
              Offset(19.18039906547299, 36.862333955479784),
              Offset(16.509090720567585, 35.04434211490934),
              Offset(14.703380298498667, 33.21759365821649),
              Offset(13.512146444284534, 31.556733263561572),
              Offset(12.740174664860898, 30.12862517729895),
              Offset(12.248059307884624, 28.947244716051806),
              Offset(11.939734974297815, 28.002595790430043),
              Offset(11.750425410476474, 27.27521551305395),
              Offset(11.637314290474384, 26.742992599694542),
              Offset(11.572897732210654, 26.384358993735816),
              Offset(11.54031155133882, 26.17955109507089),
              Offset(11.530083003283234, 26.111009046369567),
              Offset(11.530061897030713, 26.110865227715482),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(42.0, 32.0),
              Offset(41.803966700752746, 32.205577011286266),
              Offset(41.104447603276626, 32.89996903899956),
              Offset(39.64402995767152, 34.17517788052204),
              Offset(37.031973302731046, 35.97545970343111),
              Offset(32.44508133022271, 37.98012671725157),
              Offset(27.6644042246058, 38.77327245743646),
              Offset(22.963108117227325, 38.302914175295534),
              Offset(19.18039906547299, 36.862333955479784),
              Offset(16.509090720567585, 35.04434211490934),
              Offset(14.703380298498667, 33.21759365821649),
              Offset(13.512146444284534, 31.556733263561572),
              Offset(12.740174664860898, 30.12862517729895),
              Offset(12.248059307884624, 28.947244716051806),
              Offset(11.939734974297815, 28.002595790430043),
              Offset(11.750425410476474, 27.27521551305395),
              Offset(11.637314290474384, 26.742992599694542),
              Offset(11.572897732210654, 26.384358993735816),
              Offset(11.54031155133882, 26.17955109507089),
              Offset(11.530083003283234, 26.111009046369567),
              Offset(11.530061897030713, 26.110865227715482),
            ],
            <Offset>[
              Offset(6.0, 32.0),
              Offset(5.899914425897517, 31.66443482499171),
              Offset(5.601001082666045, 30.482888615847468),
              Offset(5.242005036683729, 28.09953280239226),
              Offset(5.346316156571252, 24.145975901906155),
              Offset(7.249241148069178, 18.317100047682345),
              Offset(10.710823881370487, 13.931896549234073),
              Offset(14.817117889097364, 11.294374466111893),
              Offset(18.288493245756, 10.248489378687303),
              Offset(20.784419638077317, 10.013509863155594),
              Offset(22.541938014255397, 10.075312777589325),
              Offset(23.798109358346892, 10.220508832423288),
              Offset(24.71461203122786, 10.370924674281323),
              Offset(25.392890381083, 10.501349297587215),
              Offset(25.896277759611298, 10.60605174724228),
              Offset(26.265268043339944, 10.685909272436422),
              Offset(26.526795349038366, 10.74364670273436),
              Offset(26.699555102368272, 10.782158496973931),
              Offset(26.79709065296033, 10.80399872839147),
              Offset(26.829561509459538, 10.811282301423006),
              Offset(26.829629554119695, 10.811297570626497),
            ],
            <Offset>[
              Offset(6.0, 32.0),
              Offset(5.899914425897517, 31.66443482499171),
              Offset(5.601001082666045, 30.482888615847468),
              Offset(5.242005036683729, 28.09953280239226),
              Offset(5.346316156571252, 24.145975901906155),
              Offset(7.249241148069178, 18.317100047682345),
              Offset(10.710823881370487, 13.931896549234073),
              Offset(14.817117889097364, 11.294374466111893),
              Offset(18.288493245756, 10.248489378687303),
              Offset(20.784419638077317, 10.013509863155594),
              Offset(22.541938014255397, 10.075312777589325),
              Offset(23.798109358346892, 10.220508832423288),
              Offset(24.71461203122786, 10.370924674281323),
              Offset(25.392890381083, 10.501349297587215),
              Offset(25.896277759611298, 10.60605174724228),
              Offset(26.265268043339944, 10.685909272436422),
              Offset(26.526795349038366, 10.74364670273436),
              Offset(26.699555102368272, 10.782158496973931),
              Offset(26.79709065296033, 10.80399872839147),
              Offset(26.829561509459538, 10.811282301423006),
              Offset(26.829629554119695, 10.811297570626497),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(6.0, 32.0),
              Offset(5.899914425897517, 31.66443482499171),
              Offset(5.601001082666045, 30.482888615847468),
              Offset(5.242005036683729, 28.09953280239226),
              Offset(5.346316156571252, 24.145975901906155),
              Offset(7.249241148069178, 18.317100047682345),
              Offset(10.710823881370487, 13.931896549234073),
              Offset(14.817117889097364, 11.294374466111893),
              Offset(18.288493245756, 10.248489378687303),
              Offset(20.784419638077317, 10.013509863155594),
              Offset(22.541938014255397, 10.075312777589325),
              Offset(23.798109358346892, 10.220508832423288),
              Offset(24.71461203122786, 10.370924674281323),
              Offset(25.392890381083, 10.501349297587215),
              Offset(25.896277759611298, 10.60605174724228),
              Offset(26.265268043339944, 10.685909272436422),
              Offset(26.526795349038366, 10.74364670273436),
              Offset(26.699555102368272, 10.782158496973931),
              Offset(26.79709065296033, 10.80399872839147),
              Offset(26.829561509459538, 10.811282301423006),
              Offset(26.829629554119695, 10.811297570626497),
            ],
            <Offset>[
              Offset(6.0, 36.0),
              Offset(5.839633683308566, 35.66398057820831),
              Offset(5.329309336323984, 34.47365089829046),
              Offset(4.546341863735712, 32.03857491308413),
              Offset(3.947281661825336, 27.893335303206097),
              Offset(4.788314785746671, 21.47048575818877),
              Offset(7.406922551270995, 16.18672159809414),
              Offset(10.98751172223972, 12.449414122039723),
              Offset(14.290737577881032, 10.382465570503403),
              Offset(16.841520256655304, 9.340052761342939),
              Offset(18.753361861827802, 8.792078295019234),
              Offset(20.194958973207576, 8.483469022266245),
              Offset(21.293826339889407, 8.297708512388375),
              Offset(22.13538517817335, 8.180000583365981),
              Offset(22.776244370563283, 8.102975309890528),
              Offset(23.25488929251534, 8.051973096940955),
              Offset(23.598629725644848, 8.018606137536025),
              Offset(23.82770064384222, 7.997835963745423),
              Offset(23.957717978081078, 7.986559676140466),
              Offset(24.001111438940168, 7.982878122636148),
              Offset(24.001202429373503, 7.982870445880305),
            ],
            <Offset>[
              Offset(6.0, 36.0),
              Offset(5.839633683308566, 35.66398057820831),
              Offset(5.329309336323984, 34.47365089829046),
              Offset(4.546341863735712, 32.03857491308413),
              Offset(3.947281661825336, 27.893335303206097),
              Offset(4.788314785746671, 21.47048575818877),
              Offset(7.406922551270995, 16.18672159809414),
              Offset(10.98751172223972, 12.449414122039723),
              Offset(14.290737577881032, 10.382465570503403),
              Offset(16.841520256655304, 9.340052761342939),
              Offset(18.753361861827802, 8.792078295019234),
              Offset(20.194958973207576, 8.483469022266245),
              Offset(21.293826339889407, 8.297708512388375),
              Offset(22.13538517817335, 8.180000583365981),
              Offset(22.776244370563283, 8.102975309890528),
              Offset(23.25488929251534, 8.051973096940955),
              Offset(23.598629725644848, 8.018606137536025),
              Offset(23.82770064384222, 7.997835963745423),
              Offset(23.957717978081078, 7.986559676140466),
              Offset(24.001111438940168, 7.982878122636148),
              Offset(24.001202429373503, 7.982870445880305),
            ],
          ),
          _PathClose(),
        ],
      ),
      _PathFrames(
        opacities: <double>[
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
          1.0,
        ],
        commands: <_PathCommand>[
          _PathMoveTo(
            <Offset>[
              Offset(6.0, 16.0),
              Offset(6.222470088677106, 15.614531066984553),
              Offset(7.071161725316092, 14.306422712262563),
              Offset(9.085869786142727, 11.907139949336411),
              Offset(13.311519331212619, 8.711520321213257),
              Offset(21.694206315186374, 6.462423500731354),
              Offset(30.07031570748504, 8.471955170698632),
              Offset(36.20036889900587, 14.155750775196541),
              Offset(38.533897479983715, 20.76099122996903),
              Offset(38.182626701431914, 26.194302454359914),
              Offset(36.59711302702814, 30.110286603895076),
              Offset(34.63761335058528, 32.76106836363335),
              Offset(32.7272901891386, 34.4927008221791),
              Offset(31.04869117038896, 35.596105690451935),
              Offset(29.664526028757855, 36.28441549314729),
              Offset(28.581655311555835, 36.70452225851578),
              Offset(27.782897949107628, 36.95396775456513),
              Offset(27.242531133855476, 37.09522522130338),
              Offset(26.933380541033216, 37.166375518103024),
              Offset(26.82984682779076, 37.188656481991416),
              Offset(26.829629554103434, 37.18870242935725),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(6.0, 16.0),
              Offset(6.222470088677106, 15.614531066984553),
              Offset(7.071161725316092, 14.306422712262563),
              Offset(9.085869786142727, 11.907139949336411),
              Offset(13.311519331212619, 8.711520321213257),
              Offset(21.694206315186374, 6.462423500731354),
              Offset(30.07031570748504, 8.471955170698632),
              Offset(36.20036889900587, 14.155750775196541),
              Offset(38.533897479983715, 20.76099122996903),
              Offset(38.182626701431914, 26.194302454359914),
              Offset(36.59711302702814, 30.110286603895076),
              Offset(34.63761335058528, 32.76106836363335),
              Offset(32.7272901891386, 34.4927008221791),
              Offset(31.04869117038896, 35.596105690451935),
              Offset(29.664526028757855, 36.28441549314729),
              Offset(28.581655311555835, 36.70452225851578),
              Offset(27.782897949107628, 36.95396775456513),
              Offset(27.242531133855476, 37.09522522130338),
              Offset(26.933380541033216, 37.166375518103024),
              Offset(26.82984682779076, 37.188656481991416),
              Offset(26.829629554103434, 37.18870242935725),
            ],
            <Offset>[
              Offset(42.0, 16.0),
              Offset(42.119273441095075, 16.516374018071716),
              Offset(42.428662704565184, 18.32937541467259),
              Offset(42.54812490043565, 21.94159775950881),
              Offset(41.3111285319893, 27.683594454682137),
              Offset(36.06395079582478, 35.01020271691918),
              Offset(28.59459512599702, 38.51093769070532),
              Offset(21.239886122259133, 38.07233071493643),
              Offset(16.251628495692138, 35.34156866251391),
              Offset(13.527101819238178, 32.27103394597236),
              Offset(12.16858814546228, 29.604397296366464),
              Offset(11.548946515009288, 27.474331231158473),
              Offset(11.311114637013635, 25.826563435488687),
              Offset(11.262012546535352, 24.572239162454554),
              Offset(11.298221100690522, 23.63118177535833),
              Offset(11.364474416879979, 22.940254245947138),
              Offset(11.431638843687892, 22.451805922237554),
              Offset(11.485090012547001, 22.130328573710905),
              Offset(11.518417313485447, 21.949395273355513),
              Offset(11.530012405933167, 21.889264075838188),
              Offset(11.53003696527787, 21.889138124802937),
            ],
            <Offset>[
              Offset(42.0, 16.0),
              Offset(42.119273441095075, 16.516374018071716),
              Offset(42.428662704565184, 18.32937541467259),
              Offset(42.54812490043565, 21.94159775950881),
              Offset(41.3111285319893, 27.683594454682137),
              Offset(36.06395079582478, 35.01020271691918),
              Offset(28.59459512599702, 38.51093769070532),
              Offset(21.239886122259133, 38.07233071493643),
              Offset(16.251628495692138, 35.34156866251391),
              Offset(13.527101819238178, 32.27103394597236),
              Offset(12.16858814546228, 29.604397296366464),
              Offset(11.548946515009288, 27.474331231158473),
              Offset(11.311114637013635, 25.826563435488687),
              Offset(11.262012546535352, 24.572239162454554),
              Offset(11.298221100690522, 23.63118177535833),
              Offset(11.364474416879979, 22.940254245947138),
              Offset(11.431638843687892, 22.451805922237554),
              Offset(11.485090012547001, 22.130328573710905),
              Offset(11.518417313485447, 21.949395273355513),
              Offset(11.530012405933167, 21.889264075838188),
              Offset(11.53003696527787, 21.889138124802937),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(42.0, 16.0),
              Offset(42.119273441095075, 16.516374018071716),
              Offset(42.428662704565184, 18.32937541467259),
              Offset(42.54812490043565, 21.94159775950881),
              Offset(41.3111285319893, 27.683594454682137),
              Offset(36.06395079582478, 35.01020271691918),
              Offset(28.59459512599702, 38.51093769070532),
              Offset(21.239886122259133, 38.07233071493643),
              Offset(16.251628495692138, 35.34156866251391),
              Offset(13.527101819238178, 32.27103394597236),
              Offset(12.16858814546228, 29.604397296366464),
              Offset(11.548946515009288, 27.474331231158473),
              Offset(11.311114637013635, 25.826563435488687),
              Offset(11.262012546535352, 24.572239162454554),
              Offset(11.298221100690522, 23.63118177535833),
              Offset(11.364474416879979, 22.940254245947138),
              Offset(11.431638843687892, 22.451805922237554),
              Offset(11.485090012547001, 22.130328573710905),
              Offset(11.518417313485447, 21.949395273355513),
              Offset(11.530012405933167, 21.889264075838188),
              Offset(11.53003696527787, 21.889138124802937),
            ],
            <Offset>[
              Offset(42.0, 12.0),
              Offset(42.22538630246601, 12.517777761542249),
              Offset(42.90619853384615, 14.357900907446863),
              Offset(43.759884509852945, 18.128995147835514),
              Offset(43.66585885175813, 24.44736028078141),
              Offset(39.74861752085834, 33.43380529842439),
              Offset(32.57188683977151, 39.07136996422343),
              Offset(24.376857043988256, 40.600018479197814),
              Offset(17.959269400168804, 39.004426856660785),
              Offset(13.850567169499653, 36.311009998593796),
              Offset(11.374155956344177, 33.58880277176081),
              Offset(9.917496515696001, 31.204288894581083),
              Offset(9.07498759074148, 29.236785710939074),
              Offset(8.597571742452605, 27.666692096657314),
              Offset(8.334783321442917, 26.44693980672826),
              Offset(8.195874559699876, 25.52824222288586),
              Offset(8.126295299747222, 24.866824239052814),
              Offset(8.093843447379264, 24.426077640310794),
              Offset(8.080338503727083, 24.17611706018137),
              Offset(8.076619249177135, 24.092742069165425),
              Offset(8.07661186374038, 24.09256727275783),
            ],
            <Offset>[
              Offset(42.0, 12.0),
              Offset(42.22538630246601, 12.517777761542249),
              Offset(42.90619853384615, 14.357900907446863),
              Offset(43.759884509852945, 18.128995147835514),
              Offset(43.66585885175813, 24.44736028078141),
              Offset(39.74861752085834, 33.43380529842439),
              Offset(32.57188683977151, 39.07136996422343),
              Offset(24.376857043988256, 40.600018479197814),
              Offset(17.959269400168804, 39.004426856660785),
              Offset(13.850567169499653, 36.311009998593796),
              Offset(11.374155956344177, 33.58880277176081),
              Offset(9.917496515696001, 31.204288894581083),
              Offset(9.07498759074148, 29.236785710939074),
              Offset(8.597571742452605, 27.666692096657314),
              Offset(8.334783321442917, 26.44693980672826),
              Offset(8.195874559699876, 25.52824222288586),
              Offset(8.126295299747222, 24.866824239052814),
              Offset(8.093843447379264, 24.426077640310794),
              Offset(8.080338503727083, 24.17611706018137),
              Offset(8.076619249177135, 24.092742069165425),
              Offset(8.07661186374038, 24.09256727275783),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(42.0, 12.0),
              Offset(42.22538630246601, 12.517777761542249),
              Offset(42.90619853384615, 14.357900907446863),
              Offset(43.759884509852945, 18.128995147835514),
              Offset(43.66585885175813, 24.44736028078141),
              Offset(39.74861752085834, 33.43380529842439),
              Offset(32.57188683977151, 39.07136996422343),
              Offset(24.376857043988256, 40.600018479197814),
              Offset(17.959269400168804, 39.004426856660785),
              Offset(13.850567169499653, 36.311009998593796),
              Offset(11.374155956344177, 33.58880277176081),
              Offset(9.917496515696001, 31.204288894581083),
              Offset(9.07498759074148, 29.236785710939074),
              Offset(8.597571742452605, 27.666692096657314),
              Offset(8.334783321442917, 26.44693980672826),
              Offset(8.195874559699876, 25.52824222288586),
              Offset(8.126295299747222, 24.866824239052814),
              Offset(8.093843447379264, 24.426077640310794),
              Offset(8.080338503727083, 24.17611706018137),
              Offset(8.076619249177135, 24.092742069165425),
              Offset(8.07661186374038, 24.09256727275783),
            ],
            <Offset>[
              Offset(6.0, 12.0),
              Offset(6.3229312318803075, 11.61579282114921),
              Offset(7.523361420980265, 10.332065476778915),
              Offset(10.234818160108134, 8.075701885898315),
              Offset(15.555284551985588, 5.400098023461183),
              Offset(25.267103519984172, 4.663978182144188),
              Offset(34.065497532306516, 8.668225867992323),
              Offset(39.59155761731576, 16.27703318845691),
              Offset(40.72409454498984, 24.108085016590273),
              Offset(39.139841854472834, 30.0780814324673),
              Offset(36.514293313228855, 34.10942912386185),
              Offset(33.744815583253256, 36.6601595585975),
              Offset(31.226861893018718, 38.20062678263231),
              Offset(29.10189988007002, 39.09038725780428),
              Offset(27.3951953205187, 39.57837027981981),
              Offset(26.083922435637483, 39.82883505984612),
              Offset(25.128742795932077, 39.94653528477588),
              Offset(24.487982707377697, 39.99564983955995),
              Offset(24.123290412440365, 40.013021521592925),
              Offset(24.001457946431486, 40.017121849607435),
              Offset(24.001202429333205, 40.017129554079396),
            ],
            <Offset>[
              Offset(6.0, 12.0),
              Offset(6.3229312318803075, 11.61579282114921),
              Offset(7.523361420980265, 10.332065476778915),
              Offset(10.234818160108134, 8.075701885898315),
              Offset(15.555284551985588, 5.400098023461183),
              Offset(25.267103519984172, 4.663978182144188),
              Offset(34.065497532306516, 8.668225867992323),
              Offset(39.59155761731576, 16.27703318845691),
              Offset(40.72409454498984, 24.108085016590273),
              Offset(39.139841854472834, 30.0780814324673),
              Offset(36.514293313228855, 34.10942912386185),
              Offset(33.744815583253256, 36.6601595585975),
              Offset(31.226861893018718, 38.20062678263231),
              Offset(29.10189988007002, 39.09038725780428),
              Offset(27.3951953205187, 39.57837027981981),
              Offset(26.083922435637483, 39.82883505984612),
              Offset(25.128742795932077, 39.94653528477588),
              Offset(24.487982707377697, 39.99564983955995),
              Offset(24.123290412440365, 40.013021521592925),
              Offset(24.001457946431486, 40.017121849607435),
              Offset(24.001202429333205, 40.017129554079396),
            ],
          ),
          _PathCubicTo(
            <Offset>[
              Offset(6.0, 12.0),
              Offset(6.3229312318803075, 11.61579282114921),
              Offset(7.523361420980265, 10.332065476778915),
              Offset(10.234818160108134, 8.075701885898315),
              Offset(15.555284551985588, 5.400098023461183),
              Offset(25.267103519984172, 4.663978182144188),
              Offset(34.065497532306516, 8.668225867992323),
              Offset(39.59155761731576, 16.27703318845691),
              Offset(40.72409454498984, 24.108085016590273),
              Offset(39.139841854472834, 30.0780814324673),
              Offset(36.514293313228855, 34.10942912386185),
              Offset(33.744815583253256, 36.6601595585975),
              Offset(31.226861893018718, 38.20062678263231),
              Offset(29.10189988007002, 39.09038725780428),
              Offset(27.3951953205187, 39.57837027981981),
              Offset(26.083922435637483, 39.82883505984612),
              Offset(25.128742795932077, 39.94653528477588),
              Offset(24.487982707377697, 39.99564983955995),
              Offset(24.123290412440365, 40.013021521592925),
              Offset(24.001457946431486, 40.017121849607435),
              Offset(24.001202429333205, 40.017129554079396),
            ],
            <Offset>[
              Offset(6.0, 16.0),
              Offset(6.22247008872931, 15.614531066985863),
              Offset(7.071161725356028, 14.306422712267109),
              Offset(9.085869786222908, 11.907139949360454),
              Offset(13.311519331206826, 8.711520321209331),
              Offset(21.69420631520211, 6.462423500762615),
              Offset(30.070315707485825, 8.471955170682651),
              Offset(36.20036889903345, 14.155750775152455),
              Offset(38.53389748002304, 20.760991229943293),
              Offset(38.18262670145813, 26.194302454353455),
              Offset(36.597113027065134, 30.110286603895844),
              Offset(34.63761335066132, 32.761068363650764),
              Offset(32.72729018913396, 34.49270082217723),
              Offset(31.048691170407302, 35.59610569046216),
              Offset(29.66452602881138, 36.28441549318417),
              Offset(28.58165531160348, 36.70452225855387),
              Offset(27.78289794916673, 36.95396775461755),
              Offset(27.24253113386635, 37.09522522131371),
              Offset(26.933380541051008, 37.16637551812059),
              Offset(26.829846827821875, 37.18865648202253),
              Offset(26.829629554079393, 37.188702429333205),
            ],
            <Offset>[
              Offset(6.0, 16.0),
              Offset(6.22247008872931, 15.614531066985863),
              Offset(7.071161725356028, 14.306422712267109),
              Offset(9.085869786222908, 11.907139949360454),
              Offset(13.311519331206826, 8.711520321209331),
              Offset(21.69420631520211, 6.462423500762615),
              Offset(30.070315707485825, 8.471955170682651),
              Offset(36.20036889903345, 14.155750775152455),
              Offset(38.53389748002304, 20.760991229943293),
              Offset(38.18262670145813, 26.194302454353455),
              Offset(36.597113027065134, 30.110286603895844),
              Offset(34.63761335066132, 32.761068363650764),
              Offset(32.72729018913396, 34.49270082217723),
              Offset(31.048691170407302, 35.59610569046216),
              Offset(29.66452602881138, 36.28441549318417),
              Offset(28.58165531160348, 36.70452225855387),
              Offset(27.78289794916673, 36.95396775461755),
              Offset(27.24253113386635, 37.09522522131371),
              Offset(26.933380541051008, 37.16637551812059),
              Offset(26.829846827821875, 37.18865648202253),
              Offset(26.829629554079393, 37.188702429333205),
            ],
          ),
          _PathClose(),
        ],
      ),
    ],
    matchTextDirection: true,
  );
}