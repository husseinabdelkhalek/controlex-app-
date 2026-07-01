import 'package:flutter/material.dart';
import '../core/haptic_helper.dart';

class GridItemData {
  final String id;
  int x, y, w, h;
  final Widget child;

  GridItemData({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.child,
  });
}

class InteractiveGrid extends StatefulWidget {
  final List<GridItemData> items;
  final int crossAxisCount;
  final bool isEditMode;
  final Function(GridItemData)? onItemChanged;
  final Function(GridItemData)? onMoveRequest;
  /// Called with true when a drag/resize starts, false when it ends.
  /// The parent should lock scrolling while true.
  final ValueChanged<bool>? onInteractionStateChanged;

  const InteractiveGrid({
    super.key,
    required this.items,
    this.crossAxisCount = 4,
    this.isEditMode = false,
    this.onItemChanged,
    this.onMoveRequest,
    this.onInteractionStateChanged,
  });

  /// Packs items so none overlap.  Used once after loading from server.
  static void pack(List<GridItemData> list, int crossAxisCount) {
    for (int i = 0; i < list.length; i++) {
      bool overlapping = true;
      while (overlapping) {
        overlapping = false;
        for (int j = 0; j < i; j++) {
          if (_checkOverlap(list[i], list[j])) {
            list[i].x += 1;
            if (list[i].x + list[i].w > crossAxisCount) {
              list[i].x = 0;
              list[i].y += 1;
            }
            overlapping = true;
            break;
          }
        }
      }
    }
  }

  static bool _checkOverlap(GridItemData a, GridItemData b) {
    return a.x < b.x + b.w &&
        a.x + a.w > b.x &&
        a.y < b.y + b.h &&
        a.y + a.h > b.y;
  }

  @override
  State<InteractiveGrid> createState() => _InteractiveGridState();
}

class _InteractiveGridState extends State<InteractiveGrid> {
  // ── Drag-to-move state ──────────────────────────────────────────────
  GridItemData? _dragItem;
  double _dragLeft = 0;
  double _dragTop = 0;
  bool _isDragging = false;

  // ── Drag-to-resize state ────────────────────────────────────────────
  GridItemData? _resizeItem;
  double _resizePixelW = 0;
  double _resizePixelH = 0;
  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellW = constraints.maxWidth / widget.crossAxisCount;
        final double cellH = cellW; // square cells

        // Compute how tall the grid needs to be
        int maxY = 0;
        for (var item in widget.items) {
          if (item.y + item.h > maxY) maxY = item.y + item.h;
        }
        // Account for items being dragged / resized beyond current bounds
        if (_dragItem != null) {
          int dY = (_dragTop / cellH).round();
          if (dY + _dragItem!.h > maxY) maxY = dY + _dragItem!.h;
        }
        if (_resizeItem != null && _isResizing) {
          int rh = (_resizePixelH / cellH).round().clamp(1, 99);
          if (_resizeItem!.y + rh > maxY) maxY = _resizeItem!.y + rh;
        }

        return SizedBox(
          height: (maxY + 1) * cellH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Ghost placeholder for the currently dragged item ──
              if (_dragItem != null && _isDragging)
                _ghostPlaceholder(_dragItem!, cellW, cellH),

              // ── Static / Animated items ────────────────────────────
              ...() {
                final List<GridItemData> sorted = List.from(widget.items);
                if (_dragItem != null) {
                  // Move dragItem to the end of the list so it renders on top
                  final index = sorted.indexWhere((item) => item.id == _dragItem!.id);
                  if (index != -1) {
                    final item = sorted.removeAt(index);
                    sorted.add(item);
                  }
                }
                return sorted.map((item) => _buildItem(item, cellW, cellH));
              }(),

              // ── Drop-zone outline (snaps to grid while dragging) ───
              if (_dragItem != null && _isDragging)
                _dropZoneIndicator(cellW, cellH),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Ghost placeholder (shown at original pos while dragging)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _ghostPlaceholder(
      GridItemData item, double cellW, double cellH) {
    return Positioned(
      left: item.x * cellW,
      top: item.y * cellH,
      width: item.w * cellW,
      height: item.h * cellH,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Drop-zone outline (snapped grid preview for move)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _dropZoneIndicator(double cellW, double cellH) {
    return Positioned(
      left: (_dragLeft / cellW).round() * cellW,
      top: (_dragTop / cellH).round() * cellH,
      width: _dragItem!.w * cellW,
      height: _dragItem!.h * cellH,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
            width: 2,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Build each grid item
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildItem(GridItemData item, double cellW, double cellH) {
    // If this item is being resized, use the live pixel dimensions
    final bool isBeingResized =
        _resizeItem?.id == item.id && _isResizing;
    final bool isBeingDragged =
        _dragItem?.id == item.id && _isDragging;

    final double displayW =
        isBeingResized ? _resizePixelW : item.w * cellW;
    final double displayH =
        isBeingResized ? _resizePixelH : item.h * cellH;

    final double displayLeft =
        isBeingDragged ? _dragLeft : item.x * cellW;
    final double displayTop =
        isBeingDragged ? _dragTop : item.y * cellH;

    return AnimatedPositioned(
      key: ValueKey(item.id),
      duration: Duration(
          milliseconds: (isBeingResized || isBeingDragged) ? 0 : 220),
      curve: Curves.easeOutCubic,
      left: displayLeft,
      top: displayTop,
      width: displayW,
      height: displayH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Widget content ──────────────────────────────────────
          Positioned.fill(child: item.child),

          // ── Edit-mode overlays ─────────────────────────────────
          if (widget.isEditMode) ...[
            // Edit-mode glow border
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            // ── Drag handle — top strip ──────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _DragHandle(
                onDragStart: (event) {
                  HapticHelper.lightFeedback();
                  widget.onInteractionStateChanged?.call(true);
                  setState(() {
                    _dragItem = item;
                    _isDragging = true;
                    _dragLeft = item.x * cellW;
                    _dragTop = item.y * cellH;
                  });
                },
                onDragUpdate: (event) {
                  setState(() {
                    _dragLeft += event.delta.dx;
                    _dragTop += event.delta.dy;

                    // Real-time grid snapping and collision resolution while dragging!
                    int snappedX = (_dragLeft / cellW).round();
                    int snappedY = (_dragTop / cellH).round();

                    if (snappedX < 0) snappedX = 0;
                    if (snappedX + item.w > widget.crossAxisCount) {
                      snappedX = widget.crossAxisCount - item.w;
                    }
                    if (snappedY < 0) snappedY = 0;

                    if (snappedX != item.x || snappedY != item.y) {
                      item.x = snappedX;
                      item.y = snappedY;
                      _resolveCollisions(item);
                      widget.onItemChanged?.call(item);
                    }
                  });
                },
                onDragEnd: (event) {
                  HapticHelper.lightFeedback();
                  widget.onInteractionStateChanged?.call(false);
                  setState(() {
                    int finalX = (_dragLeft / cellW).round();
                    int finalY = (_dragTop / cellH).round();

                    if (finalX < 0) finalX = 0;
                    if (finalX + item.w > widget.crossAxisCount) {
                      finalX = widget.crossAxisCount - item.w;
                    }
                    if (finalY < 0) finalY = 0;

                    item.x = finalX;
                    item.y = finalY;
                    _resolveCollisions(item);
                    _dragItem = null;
                    _isDragging = false;
                  });
                  widget.onItemChanged?.call(item);
                },
              ),
            ),

            // ── Resize handle — bottom right (DRAG to resize) ────
            Positioned(
              right: 2,
              bottom: 2,
              child: _ResizeHandle(
                onResizeStart: () {
                  HapticHelper.lightFeedback();
                  widget.onInteractionStateChanged?.call(true);
                  setState(() {
                    _resizeItem = item;
                    _isResizing = true;
                    _resizePixelW = item.w * cellW;
                    _resizePixelH = item.h * cellH;
                  });
                },
                onResizeUpdate: (delta) {
                  setState(() {
                    _resizePixelW += delta.dx;
                    _resizePixelH += delta.dy;

                    // Enforce minimum 1 cell
                    if (_resizePixelW < cellW) _resizePixelW = cellW;
                    if (_resizePixelH < cellH) _resizePixelH = cellH;

                    // Enforce max width
                    final maxW =
                        (widget.crossAxisCount - item.x) * cellW;
                    if (_resizePixelW > maxW) _resizePixelW = maxW;

                    // Real-time grid snapping and collision resolution while resizing!
                    int snappedW = (_resizePixelW / cellW).round();
                    int snappedH = (_resizePixelH / cellH).round();
                    if (snappedW < 1) snappedW = 1;
                    if (snappedH < 1) snappedH = 1;
                    if (item.x + snappedW > widget.crossAxisCount) {
                      snappedW = widget.crossAxisCount - item.x;
                    }

                    if (snappedW != item.w || snappedH != item.h) {
                      item.w = snappedW;
                      item.h = snappedH;
                      _resolveCollisions(item);
                      widget.onItemChanged?.call(item);
                    }
                  });
                },
                onResizeEnd: () {
                  HapticHelper.lightFeedback();
                  widget.onInteractionStateChanged?.call(false);
                  setState(() {
                    int newW = (_resizePixelW / cellW).round();
                    int newH = (_resizePixelH / cellH).round();

                    if (newW < 1) newW = 1;
                    if (newH < 1) newH = 1;
                    if (item.x + newW > widget.crossAxisCount) {
                      newW = widget.crossAxisCount - item.x;
                    }

                    item.w = newW;
                    item.h = newH;
                    _resizeItem = null;
                    _isResizing = false;
                    _resolveCollisions(item);
                  });
                  widget.onItemChanged?.call(item);
                },
              ),
            ),

            // ── Move-to-page button — bottom left ────────────────
            if (widget.onMoveRequest != null)
              Positioned(
                left: 6,
                bottom: 6,
                child: _EditButton(
                  icon: Icons.drive_file_move_rounded,
                  color: const Color(0xFFBB86FC),
                  onTap: () {
                    HapticHelper.lightFeedback();
                    widget.onMoveRequest?.call(item);
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Collision resolution
  // ═══════════════════════════════════════════════════════════════════════
  void _resolveCollisions(GridItemData activeItem) {
    const int maxPasses = 12;
    for (int pass = 0; pass < maxPasses; pass++) {
      bool changed = false;
      for (int i = 0; i < widget.items.length; i++) {
        for (int j = 0; j < widget.items.length; j++) {
          if (i == j) continue;
          GridItemData a = widget.items[i];
          GridItemData b = widget.items[j];
          if (InteractiveGrid._checkOverlap(a, b)) {
            changed = true;
            if (a.id == activeItem.id) {
              b.y = a.y + a.h;
            } else if (b.id == activeItem.id) {
              a.y = b.y + b.h;
            } else {
              if (b.y >= a.y) {
                b.y = a.y + a.h;
              } else {
                a.y = b.y + b.h;
              }
            }
          }
        }
      }
      if (!changed) break;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Drag Handle — top strip that initiates drag-to-move (Immediate Listener)
// ═══════════════════════════════════════════════════════════════════════════
class _DragHandle extends StatelessWidget {
  final void Function(PointerDownEvent) onDragStart;
  final void Function(PointerMoveEvent) onDragUpdate;
  final void Function(PointerUpEvent) onDragEnd;

  const _DragHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: onDragStart,
      onPointerMove: onDragUpdate,
      onPointerUp: onDragEnd,
      onPointerCancel: (_) => onDragEnd(const PointerUpEvent()),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.drag_handle_rounded,
            size: 20,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Resize Handle — bottom-right corner drag for resize
// ═══════════════════════════════════════════════════════════════════════════
class _ResizeHandle extends StatefulWidget {
  final VoidCallback onResizeStart;
  final void Function(Offset delta) onResizeUpdate;
  final VoidCallback onResizeEnd;

  const _ResizeHandle({
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        setState(() => _active = true);
        widget.onResizeStart();
      },
      onPanUpdate: (d) {
        widget.onResizeUpdate(d.delta);
      },
      onPanEnd: (_) {
        setState(() => _active = false);
        widget.onResizeEnd();
      },
      onPanCancel: () {
        if (_active) {
          setState(() => _active = false);
          widget.onResizeEnd();
        }
      },
      child: AnimatedScale(
        scale: _active ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _active
                ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00E5FF),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.zoom_out_map_rounded,
            size: 15,
            color: Color(0xFF00E5FF),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Small icon button (move-to-page)
// ═══════════════════════════════════════════════════════════════════════════
class _EditButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _EditButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_EditButton> createState() => _EditButtonState();
}

class _EditButtonState extends State<_EditButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.82 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _pressed
                ? widget.color.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(widget.icon, size: 15, color: widget.color),
        ),
      ),
    );
  }
}
