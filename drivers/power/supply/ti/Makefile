obj-$(CONFIG_BQ2597X_CHARGE_PUMP)	+= bq2597x_charger.o pd_policy_manager.o cp_qc30.o

ifeq ($(cc-name),gcc)
CFLAGS_REMOVE_bq2597x_charger.o += -mgeneral-regs-only
endif
