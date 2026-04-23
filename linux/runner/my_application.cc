#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <glib.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static FlMethodChannel* window_drag_channel = nullptr;
static FlMethodChannel* window_style_channel = nullptr;

static void apply_window_decorations(GtkWindow* window,
                                     gboolean use_system_decorations) {
  gtk_window_set_titlebar(window, nullptr);
  gtk_window_set_decorated(window, use_system_decorations);
}

static GdkWindowEdge parse_window_edge(FlValue* args) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return GDK_WINDOW_EDGE_SOUTH_EAST;
  }

  FlValue* edge_value = fl_value_lookup_string(args, "edge");
  if (edge_value == nullptr || fl_value_get_type(edge_value) != FL_VALUE_TYPE_STRING) {
    return GDK_WINDOW_EDGE_SOUTH_EAST;
  }

  const gchar* edge = fl_value_get_string(edge_value);
  if (g_strcmp0(edge, "top") == 0) return GDK_WINDOW_EDGE_NORTH;
  if (g_strcmp0(edge, "topRight") == 0) return GDK_WINDOW_EDGE_NORTH_EAST;
  if (g_strcmp0(edge, "right") == 0) return GDK_WINDOW_EDGE_EAST;
  if (g_strcmp0(edge, "bottomRight") == 0) return GDK_WINDOW_EDGE_SOUTH_EAST;
  if (g_strcmp0(edge, "bottom") == 0) return GDK_WINDOW_EDGE_SOUTH;
  if (g_strcmp0(edge, "bottomLeft") == 0) return GDK_WINDOW_EDGE_SOUTH_WEST;
  if (g_strcmp0(edge, "left") == 0) return GDK_WINDOW_EDGE_WEST;
  if (g_strcmp0(edge, "topLeft") == 0) return GDK_WINDOW_EDGE_NORTH_WEST;
  return GDK_WINDOW_EDGE_SOUTH_EAST;
}

static void window_style_method_call_cb(FlMethodChannel* channel,
                                        FlMethodCall* method_call,
                                        gpointer user_data) {
  (void)channel;
  const gchar* method = fl_method_call_get_name(method_call);
  GtkWindow* window = GTK_WINDOW(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "setUseSystemDecorations") == 0) {
    gboolean enabled = FALSE;
    FlValue* args = fl_method_call_get_args(method_call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* value = fl_value_lookup_string(args, "enabled");
      if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL) {
        enabled = fl_value_get_bool(value);
      }
    }
    apply_window_decorations(window, enabled);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to respond on app/window_style channel: %s", error->message);
  }
}

static void window_drag_method_call_cb(FlMethodChannel* channel,
                                       FlMethodCall* method_call,
                                       gpointer user_data) {
  (void)channel;
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  GtkWindow* window = GTK_WINDOW(user_data);
  if (g_strcmp0(method, "startDrag") == 0) {
    GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
    GdkSeat* seat =
        display != nullptr ? gdk_display_get_default_seat(display) : nullptr;
    GdkDevice* pointer = seat != nullptr ? gdk_seat_get_pointer(seat) : nullptr;
    gint x_root = 0;
    gint y_root = 0;
    if (pointer != nullptr) {
      gdk_device_get_position(pointer, nullptr, &x_root, &y_root);
    }
    gtk_window_begin_move_drag(window, 1, x_root, y_root,
                               gtk_get_current_event_time());
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "startResize") == 0) {
    GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
    GdkSeat* seat =
        display != nullptr ? gdk_display_get_default_seat(display) : nullptr;
    GdkDevice* pointer = seat != nullptr ? gdk_seat_get_pointer(seat) : nullptr;
    gint x_root = 0;
    gint y_root = 0;
    if (pointer != nullptr) {
      gdk_device_get_position(pointer, nullptr, &x_root, &y_root);
    }
    gtk_window_begin_resize_drag(
        window, parse_window_edge(fl_method_call_get_args(method_call)), 1,
        x_root, y_root, gtk_get_current_event_time());
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "minimize") == 0) {
    gtk_window_iconify(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "maximize") == 0) {
    gtk_window_maximize(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "isMaximized") == 0) {
    gboolean is_maximized = FALSE;
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
    if (gdk_window != nullptr) {
      const GdkWindowState state = gdk_window_get_state(gdk_window);
      is_maximized = (state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
    }
    response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(is_maximized)));
  } else if (g_strcmp0(method, "toggleMaximize") == 0) {
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
    if (gdk_window != nullptr) {
      const GdkWindowState state = gdk_window_get_state(gdk_window);
      if (state & GDK_WINDOW_STATE_MAXIMIZED) {
        gtk_window_unmaximize(window);
      } else {
        gtk_window_maximize(window);
      }
    } else {
      gtk_window_maximize(window);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "close") == 0) {
    gtk_window_close(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send window drag response: %s", error->message);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gtk_window_set_title(window, "Programmer Calculator");
  apply_window_decorations(window, FALSE);
  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  if (window_drag_channel == nullptr) {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    window_drag_channel = fl_method_channel_new(messenger, "app/window_drag",
                                                FL_METHOD_CODEC(codec));
  }
  fl_method_channel_set_method_call_handler(window_drag_channel,
                                            window_drag_method_call_cb, window,
                                            nullptr);
  if (window_style_channel == nullptr) {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    window_style_channel = fl_method_channel_new(
        messenger, "app/window_style", FL_METHOD_CODEC(codec));
  }
  fl_method_channel_set_method_call_handler(window_style_channel,
                                            window_style_method_call_cb, window,
                                            nullptr);

  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_show(GTK_WIDGET(window));
  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;
  return TRUE;
}

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
