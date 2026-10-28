# API de RtsKit por pieza

Todo está en `addons/rts_kit/`. Los puntos del kit son `Vector3` con el suelo en XZ (2D: `(x, 0, y)`).

## Núcleo

| Clase | Miembros |
|---|---|
| `RtsSpace` (estático) | `ahead(yaw)`, `right(yaw)`, `yaw_of_direction(v)`, `from_2d(v2)`, `to_2d(v3)`, `position_of(node)`, `place(node, point)`, `yaw_of_node(node)`, `screen_of(viewport, point, is_2d)`, `world_2d_at(viewport, screen)` |
| `RtsUnit` (Node, hijo del cuerpo) | exports `owner_slot`, `team`, `kind`, `tags`, `selectable`, `orderable`, `targetable`, `size`, `center`, `icon`, `refused`, `formation`; `body`, `selected`; `of(node)`, `all(tree)`; `team_id()`, `accepts(cmd)`, `is_foe(other)`, `relation_to(slot, team)` (`own` / `ally` / `neutral` / `enemy`), `position()`, `center_point()`, `facing_yaw()`, `is_2d()`, `has_tag(t)`; cola: `give(order, queue)`, `complete()`, `fail(reason)`, `stop()`, `current_order()`, `queued_orders()`, `is_idle()`; signals `selected_changed`, `order_started(order, replaced)`, `order_ended(order, result)`, `order_queued(order)` |
| `RtsUnitOrder` | `command`, `type`, `target`, `point`, `slot`, `facing`, `formation`, `queued`; `spot()`, `spot_2d()`, `has_target()`, `is_repeat_of(other)` |
| `RtsOrder` | `command`, `units`, `point`, `target`, `facing`, `formation`, `queue`; `make(...)`, `to_array(id_of)`, `from_array(data, root, node_of)` (null si está mal formado), `FORMAT`, `MAX_UNITS` |
| `RtsCommandType` (Resource) | `id`, `display_name`, `icon`, `target` (NONE / POINT / BODY / POINT_OR_BODY), `role` (MOVE / ATTACK / GUARD), `scope` (SELECTION / SIDE), `uses_formation`, `retarget_nearest`, `to_anchor`, `tone`, `ends_on_its_own` |
| `RtsCommandCatalog` | `commands`; `find(id)`, `has_id(id)` |

## Órdenes

| Clase | Miembros |
|---|---|
| `RtsOrders` (Node) | exports `commands`, `formations`, `local_slot`, `max_units`, `spacing_per_size`, `spacing_base`, `max_spacing`, `retarget_range`, `anchor_tag`; Callables `send`, `anchor_for(slot)`, `closest_foe(unit, point, reach)`; `request(order)`, `issue(...)`, `apply(order, from_slot) -> bool`, `apply_units(slot, units, command, …)`, `can_order(unit, slot)`, `spacing_for(units)`, static `match_greedy`, `match_rows`; `FORMATION`; signals `requested(order)`, `applied(order, units)`; debug `last_apply_us`, `last_rows`, `last_width` |
| `RtsFormation` (Resource) | `id`, `display_name`, `icon`; `slots(count, spacing, target_distance, role)`, `row_count`, `match_row_size`, `row_width` |
| `RtsRowFormation` / `RtsArcFormation` / `RtsWedgeFormation` | filas (`row_size`, `anchor`, `stagger`, `guard_flank`, `guard_behind`), arcos (`arc_deg`), cuña (`attack_forward`) |
| `RtsFormationCatalog` | `formations`, `default_id`; `find`, `has_id`, `default_formation` |

## Selección y entrada

| Clase | Miembros |
|---|---|
| `RtsSelection` | exports `local_slot`, `box`, `occluder_mask`, `occluder`, `max_size`, `group_count`, `new_units_group`, `same_type_radius`, `double_click_s`, `double_click_px`; `units()`, `bodies()`, `size()`, `count`, `has(u)`, `group(i)`, `can_select(u)`, `clear()`, `select_only(list)`, `remove(list)`, `click(unit, screen, shift, ctrl)`, `select_rect(from, to, additive)`, `show_box`, `hide_box`, `define_group(i)`, `extend_group(i)`, `select_group(i)`, `drop(u)`, `add_new(u)`, `same_kind_near(u)`; signal `changed(units)` |
| `RtsPointer` | exports `dimension`, `camera`, `local_slot`, `local_team`, `ground_mask`, `unit_mask`, `pick_mask`, `ground`, `pick_px`, `ground_bounds_2d`; `ground_at(screen)`, `unit_under(screen, skip)`, `body_under(screen, skip)`, `is_empty_at`, `relation(body)`, `is_enemy`, `camera_yaw()`, `camera_dragged()`, `action_pointer()`, `pointer_now()`, `cast_3d` |
| `RtsCommandInput` | exports `local_slot`, `local_team`, `install_keymap`, `command_on_macos`, `command_keys` (acción -> orden), `formation_action_prefix`, pieces; `run_command(id)`, `set_formation(id)`, `right_at`, `left_at`, `context_kind` |
| `RtsSelectInput` | `select_action`, `rect_threshold_px`, `view`; `left_at(screen, shift, ctrl)`, `is_boxing()`; signals `armed_clicked(mode, screen)`, `clicked_other(body)`, `clicked_empty` |
| `RtsOrderButton` | `order_action`, `menu_action`, `menu` (`RtsOrderMenu` opcional), `view`; `is_open()` |
| `RtsOrderInput` | exports `context_orders`, `point_contexts`, `ground_orders`, `say_orders`; Callable `classify(body)`; `right_at`, `context_of`, `context_kind`, `icon_at`, `aim(command, body, ground)`, `run_entry(entry, screen)`, `run_command(id, screen)`, `retreat`, `order_in_formation`, `set_formation`, `give`; signals `ordered(command, point, target)`, `custom_entry(entry, screen)` |
| `RtsArmedCommand` | `mode`, `payload`, `commands`; `is_armed()`, `is_order()`, `cancel()`, `arm_order(id, replace)`, `arm(kind, payload, accepts, replace, icon)` |
| `RtsCommandState` | `armed`, `armed_icon`, `armed_accepts`, `aim_status`, `aim_site`, `cues`; `arm`, `disarm`, `show_aim`, `say`, `is_reason`; signals `armed_changed`, `said(text, cue)`, `aim_changed` |
| `RtsGroupKeys` | `handle(event) -> bool` (con Alt apretado nunca es tecla de grupo) |
| `RtsArmedPreview` | `modes`, `hz`; Callable `answer(mode, payload, screen, ground) -> [status, site]`; `preview()` |
| `RtsWorldInput` (estático) | `modal_group`, `blocked(from)` |
| `RtsKeymap` (estático) | `install(command_on_macos)`, `bindings(command_on_macos)` |
| `RtsRefusal` (constantes) | `NO_GROUND`, `NOBODY`, `NO_ANCHOR`, `NO_TARGET`, `NOT_TAKEN` |

## Interfaces de comandos (todas opcionales)

| Clase | Miembros |
|---|---|
| `RtsMenuEntry` (Resource) | `id`, `kind` (COMMAND / FORMATION / CUSTOM), `command`, `formation`, `label`, `icon`, `hotkey_action`; `for_command`, `for_formation`, `from_catalogs(...)` |
| `RtsCommandCard` (GridContainer) | `order_input`, `command_input`, `entries`, `commands`, `show_formations`, `button_size`; `rebuild()`, `buttons()`, `key_text(action)`; signal `entry_pressed(entry)` |
| `RtsOrderMenu` (Control, base) | `hold_s`; `open_at(screen, context)`, `point_at(screen)`, `confirm()`, `cancel()`, `is_open()`; signals `entry_chosen(entry)`, `cancelled` |
| `RtsRadialMenu` (`rts_radial_menu.tscn`) | `layout`; `origin()`, `entry_at`; signals `opened`, `hovered_changed` |
| `RtsRadialLayout` / `RtsRadialRing` | rings (`entries`, `fill` NONE / COMMANDS / FORMATIONS, `commands`, `width_px`), `commands`, `formations`, `center_icon`, `context_icons`, `dead_zone_px`, `icon_px`; `ring_entries()`, `locate`, `entry_at`, `ring_mid` |

## Señales y pings

`RtsCueSet` (íconos de apuntar, ícono de rechazo, `refusals`, `reason_texts`, cursores libre / con blanco / bloqueado / HUD), `RtsTargetProbe` (`kind`, `hovered`, `classify`, `world_view`, `hud_controls`), `RtsCursorSkin`, `rts_command_cue.tscn` (`RtsCommandCue` + `RtsRefusalReason`), `RtsPing3D` / `RtsPing2D` (`play(point, tone)`).

## Cámaras

`RtsCamera3D` (`mode` FOLLOW / FREE, `follow`, `set_follow`, `focus`, `yaw`, `is_dragging`, `free_target`, `free_pitch_deg`, `free_min_distance`, `free_max_distance`, `pan_speed`, `bounds`, `ground`, `ground_clearance`, `height_at`, `height_of`, `edge_area`, `wheel_blockers`, `effect`, `follow_yaw_property`, la fórmula de seguir, `debug_pointer`), `RtsCamera2D` (`mode`, `follow`, `focus`, `yaw`, `bounds`, `can_turn`, `min_zoom`, `max_zoom`, `pan_speed`), `RtsCameraEffect` (`offset()`, `roll()`).
