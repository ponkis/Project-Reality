#include <stdbool.h>

#include "mod.h"
#include <libultraship/libultraship.h>
#include "port/api/ui.h"
#include "port/events/Events.h"

#define PR_SIDEBAR_NAME "Project Reality"
#define PR_CVAR_FPS "gSettings.InterpolationFPS"
#define PR_CVAR_MATCH_REFRESH "gSettings.MatchRefreshRate"

static ListenerID sGameLoopTickListener = -1;
static C_WidgetConfig sSeparatorWidget = { 0 };
static C_WidgetConfig sTextWidget = { 0 };

static bool ApplyFramePolicy(void) {
    bool changed = false;

    if (CVarGetInteger(PR_CVAR_FPS, -1) != 30) {
        changed = true;
    }

    if (CVarGetInteger(PR_CVAR_MATCH_REFRESH, -1) != 0) {
        changed = true;
    }

    CVarSetInteger(PR_CVAR_FPS, 30);
    CVarSetInteger(PR_CVAR_MATCH_REFRESH, 0);
    return changed;
}

static void OnGameLoopTick(IEvent* event) {
    (void)event;
    ApplyFramePolicy();
}

static void SetupStatusUI(void) {
    sSeparatorWidget.type = C_WIDGET_SEPARATOR_TEXT;
    sTextWidget.type = C_WIDGET_TEXT;

    C_AddSidebarEntry(PR_SIDEBAR_NAME, 1);
    C_AddWidget(PR_SIDEBAR_NAME, 1, "Runtime Status", &sSeparatorWidget);
    C_AddWidget(PR_SIDEBAR_NAME, 1, "Core mod: loaded", &sTextWidget);
    C_AddWidget(PR_SIDEBAR_NAME, 1, "Frame rate: locked to 30 FPS", &sTextWidget);
    C_AddWidget(PR_SIDEBAR_NAME, 1, "Refresh-rate matching: disabled", &sTextWidget);
}

MOD_INIT() {
    if (ApplyFramePolicy()) {
        CVarSave();
    }

    SetupStatusUI();
    sGameLoopTickListener = REGISTER_LISTENER(GameLoopTick, EVENT_PRIORITY_NORMAL, OnGameLoopTick);
}

MOD_EXIT() {
    if (sGameLoopTickListener >= 0) {
        UNREGISTER_LISTENER(GameLoopTick, sGameLoopTickListener);
        sGameLoopTickListener = -1;
    }

    C_RemoveSidebarEntry(PR_SIDEBAR_NAME);
}
