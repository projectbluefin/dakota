/* cc-updates-panel.h
 *
 * Copyright 2026 Project Bluefin Contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <shell/cc-panel.h>
#include <adwaita.h>

G_BEGIN_DECLS

#define CC_TYPE_UPDATES_PANEL (cc_updates_panel_get_type ())
G_DECLARE_FINAL_TYPE (CcUpdatesPanel, cc_updates_panel, CC, UPDATES_PANEL, CcPanel)

G_END_DECLS
