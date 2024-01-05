/*
 * Copyright (c) 2016-2018, The Linux Foundation. All rights reserved.
 * Copyright (C) 2021 XiaoMi, Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 and
 * only version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */

#ifndef _DSI_PANEL_MI_H_
#define _DSI_PANEL_MI_H_

#define DISPPARAM_THERMAL_SET             0x1

enum bkl_dimming_state {
    STATE_NONE,
    STATE_DIM_BLOCK,
    STATE_DIM_RESTORE,
    STATE_ALL
};

enum DISPPARAM_MODE {
    DISPPARAM_HBM_ON = 0x10000,
    DISPPARAM_DC_ON = 0x40000,
    DISPPARAM_DC_OFF = 0x50000,
    DISPPARAM_BC_120HZ = 0x60000,
    DISPPARAM_BC_60HZ = 0x70000,
    DISPPARAM_HBM_OFF = 0xF0000,
    DISPPARAM_DOZE_BRIGHTNESS_HBM = 0x600000,
    DISPPARAM_DOZE_BRIGHTNESS_LBM = 0x700000,
    DISPPARAM_CRC_OFF = 0xF00000,
    DISPPARAM_FLAT_MODE_ON = 0x5000000,
    DISPPARAM_FLAT_MODE_OFF = 0x6000000,
};

int panel_disp_param_send_lock(struct dsi_panel *panel, int param);

#endif /* _DSI_PANEL_MI_H_ */
