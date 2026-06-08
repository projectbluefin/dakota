/* cc-updates-panel.c
 *
 * Copyright 2026 Project Bluefin Contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 *
 * gnome-control-center "Software Updates" panel — embeds the finupdate
 * backend (libfinupdate.so) for bootc image management.
 */

#include <adwaita.h>
#include <glib/gi18n.h>

#include "cc-updates-panel.h"
#include "shell/cc-panel.h"

#include "finupdate.h"

struct _CcUpdatesPanel
{
  CcPanel               parent_instance;

  AdwBin               *content_bin;

  /* Rust backend handle. Created in init, freed in dispose. */
  Handle               *backend;
};

G_DEFINE_FINAL_TYPE (CcUpdatesPanel, cc_updates_panel, CC_TYPE_PANEL)

/* ───── GObject lifecycle ───── */

static void
cc_updates_panel_dispose (GObject *object)
{
  CcUpdatesPanel *self = CC_UPDATES_PANEL (object);

  if (self->backend != NULL)
    {
      finupdate_free (self->backend);
      self->backend = NULL;
    }

  G_OBJECT_CLASS (cc_updates_panel_parent_class)->dispose (object);
}

static void
cc_updates_panel_class_init (CcUpdatesPanelClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (klass);

  object_class->dispose = cc_updates_panel_dispose;

  gtk_widget_class_set_template_from_resource (
      widget_class,
      "/org/gnome/control-center/updates/cc-updates-panel.ui");

  gtk_widget_class_bind_template_child (widget_class, CcUpdatesPanel, content_bin);
}

static void
cc_updates_panel_init (CcUpdatesPanel *self)
{
  gtk_widget_init_template (GTK_WIDGET (self));

  self->backend = finupdate_new ();
  if (self->backend == NULL)
    {
      GtkWidget *label = gtk_label_new (_("Backend unavailable"));
      adw_bin_set_child (self->content_bin, label);
      return;
    }

  GtkWidget *updates_widget = (GtkWidget *) finupdate_panel_widget_new (self->backend);
  if (updates_widget != NULL)
    {
      adw_bin_set_child (self->content_bin, updates_widget);
    }
  else
    {
      GtkWidget *label = gtk_label_new (_("Failed to initialize updates interface"));
      adw_bin_set_child (self->content_bin, label);
    }
}
