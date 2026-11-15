#!/usr/bin/env bash
# Make SELinux policy switchable by the end user on the LineageOS sm7325 kernel.
#
# Port of bone-machine's 0e28b10989d27066a5c0113a32b0e84c0a82560f
# ("Make SELinux policy switchable by end user") from
# android_kernel_samsung_sm7325_a52s_5g (resukisu-aosp) to lineage-24.0.
#
# The commit itself does not apply to Lineage's tree: six of its seventeen
# files have drifted apart, its kconfig hunk comments a stanza with HTML
# syntax ("fs/proc/Kconfig:94: syntax error"), and it removes the ss_initialized
# definition while leaving two call sites behind, so even a fuzzed apply cannot
# build. This script applies the same intent per hunk instead, with exact
# anchors and post-conditions.
#
# What it changes:
#  - drops Samsung's CONFIG_ALWAYS_ENFORCE / SEC_SELINUX_DEBUG build plumbing,
#    so /sys/fs/selinux/enforce stays writable on user builds;
#  - keeps the enforcing flag in selinux_state like upstream, instead of the
#    Samsung global its RKP can pin (the global stays in sync for out-of-tree
#    users such as KernelSU/SUSFS);
#  - replaces the stale ss_initialized flag with state->initialized. This tree
#    never set state->initialized, so selinux_initialized() was always false
#    and the upstream checks that use it were dead code;
#  - fixes the inverted permissive check in
#    convert_context_handle_invalid_context();
#  - stops panicking the kernel when a policy fails to read/load;
#  - restores the upstream audit defaults and drops Samsung's /proc/avc_msg;
#  - keeps AVD_FLAGS_PERMISSIVE set for every build variant.
#
# Deliberately not ported, all Samsung-ROM specific and irrelevant here:
# the auditsc.c setsockopt audit suppression, the sdcardfs mount lock, the
# configfs mount flag, the KDP credential hooks, and the GFP_ATOMIC revert in
# context_struct_to_string().
#
# Idempotent. Usage: ./patch-selinux-switch-sm7325.sh [kernel_root]
set -euo pipefail

KROOT="${1:-.}"

[ -d "$KROOT/security/selinux" ] || {
	echo "error: $KROOT does not look like the sm7325 kernel tree" >&2
	exit 1
}
command -v python3 > /dev/null || { echo "error: python3 is required" >&2; exit 1; }

echo "Patching SELinux policy switching in $KROOT..."
python3 - "$KROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
changed = []


def patch(rel, fn):
	p = root / rel
	if not p.is_file():
		sys.exit(f"error: {rel} not found")
	src = p.read_text()
	out = fn(src)
	if out != src:
		p.write_text(out)
		changed.append(rel)


def rep(src, old, new, what):
	"""Plain substring replacement, skipped when already applied."""
	if old in src:
		return src.replace(old, new, 1)
	if new in src:
		return src
	sys.exit(f"error: {what}: anchor not found")


def resub(src, pattern, repl, what, count=1):
	"""Regex replacement with a hard failure when the anchor is missing."""
	out, n = re.subn(pattern, repl, src, count=count, flags=re.S | re.M)
	if n != count:
		sys.exit(f"error: {what}: expected {count} anchor(s), found {n}")
	return out


# ---------------------------------------------------------------------------
# security/selinux/include/security.h
# ---------------------------------------------------------------------------
def security_h(src):
	if "return state->enforcing;" not in src:
		src = rep(src,
			"\treturn selinux_enforcing; // SEC_SELINUX_PORTING_COMMON Change to use RKP",
			"\treturn state->enforcing; // SEC_SELINUX_PORTING_COMMON Change to use RKP",
			"security.h enforcing_enabled")
	if "state->enforcing = value;" not in src:
		src = rep(src,
			"\tselinux_enforcing = value; // SEC_SELINUX_PORTING_COMMON Change to use RKP",
			"\tstate->enforcing = value;\n"
			"\t/* NEON_SELINUX_SWITCH: state->enforcing is authoritative, the\n"
			"\t * Samsung global is only kept in sync for out-of-tree users. */\n"
			"\tselinux_enforcing = value;",
			"security.h enforcing_set")
	if "AVD_FLAGS_PERMISSIVE\t0x0000" in src or "AVD_FLAGS_PERMISSIVE 0x0000" in src:
		src = resub(src,
			r"#ifdef CONFIG_ALWAYS_ENFORCE\n#define AVD_FLAGS_PERMISSIVE\s*0x0000\n#else\n(#[^\n]*AVD_FLAGS_PERMISSIVE\s*0x0001\n)#endif\n",
			r"\1",
			"security.h AVD_FLAGS_PERMISSIVE")
	return src


# ---------------------------------------------------------------------------
# security/selinux/include/avc_ss.h
# ---------------------------------------------------------------------------
def avc_ss_h(src):
	return rep(src,
		"extern int ss_initialized; // SEC_SELINUX_PORTING_COMMON\n", "",
		"avc_ss.h ss_initialized extern")


# ---------------------------------------------------------------------------
# security/selinux/Makefile: drop the Samsung build-variant plumbing
# ---------------------------------------------------------------------------
def selinux_makefile(src):
	if "SEC_BUILD_OPTION" not in src:
		return src
	src = resub(src,
		r"^ifeq \(\$\(TARGET_BUILD_VARIANT\), eng\)\n(?:.*\n)*?"
		r"(?=^# \] SEC_SELINUX_PORTING_COMMON)",
		"", "selinux Makefile build-variant blocks")
	if "SEC_BUILD_OPTION" in src or "CONFIG_ALWAYS_ENFORCE" in src:
		sys.exit("error: selinux Makefile: Samsung option blocks remain")
	return src


# ---------------------------------------------------------------------------
# kernel/audit.c: upstream audit defaults
# ---------------------------------------------------------------------------
def audit_c(src):
	src = rep(src, "u32\t\taudit_enabled = AUDIT_ON;",
		"u32\t\taudit_enabled = AUDIT_OFF;", "audit.c audit_enabled")
	src = rep(src, "bool\t\taudit_ever_enabled = !!AUDIT_ON;",
		"bool\t\taudit_ever_enabled = !!AUDIT_OFF;", "audit.c audit_ever_enabled")
	src = rep(src, "static u32\taudit_default = AUDIT_ON;",
		"static u32\taudit_default = AUDIT_OFF;", "audit.c audit_default")
	src = rep(src, "// Samsung Change Value from AUDIT_OFF to AUDIT_ON",
		"// NEON_SELINUX_SWITCH: upstream default, userspace enables auditing",
		"audit.c stale comment")
	return src


# ---------------------------------------------------------------------------
# fs/proc: remove the Samsung /proc/avc_msg interface
# ---------------------------------------------------------------------------
def proc_makefile(src):
	if "# proc-$(CONFIG_PROC_AVC) += proc_avc.o" in src:
		return src
	return rep(src, "proc-$(CONFIG_PROC_AVC) += proc_avc.o",
		"# NEON_SELINUX_SWITCH: Samsung debug interface, removed\n"
		"# proc-$(CONFIG_PROC_AVC) += proc_avc.o", "fs/proc/Makefile PROC_AVC")


def proc_kconfig(src):
	if "config PROC_AVC" not in src:
		return src
	# kconfig has no block comments, so the stanza goes away completely;
	# leaving an HTML-commented copy (as the original commit does) breaks
	# every 'make *config' run.
	src = resub(src, r"^config PROC_AVC\n(?:(?!^config )[\s\S])*?(?=^config )",
		"", "fs/proc/Kconfig PROC_AVC stanza")
	if "PROC_AVC" in src:
		sys.exit("error: fs/proc/Kconfig: PROC_AVC stanza remains")
	return src


# ---------------------------------------------------------------------------
# security/selinux/selinuxfs.c
# ---------------------------------------------------------------------------
def selinuxfs_c(src):
	if "#ifdef CONFIG_ALWAYS_ENFORCE" in src:
		# Keep the "#else" arm and drop Samsung's forced-enforcing arm.
		src = resub(src,
			r"#ifdef CONFIG_ALWAYS_ENFORCE\n(?:.*?\n)*?#else\n",
			"", "selinuxfs.c ALWAYS_ENFORCE write_enforce")
		src = resub(src,
			r"\n\t#endif\n(?=// \] SEC_SELINUX_PORTING_COMMON)",
			"\n", "selinuxfs.c ALWAYS_ENFORCE #endif")
	src = rep(src,
		"if (new_value != selinux_enforcing) { // SEC_SELINUX_PORTING_COMMON Change to use RKP",
		"if (new_value != old_value) { // SEC_SELINUX_PORTING_COMMON Change to use RKP",
		"selinuxfs.c sel_write_enforce compare")
	src = rep(src,
		"new_value, selinux_enforcing, // SEC_SELINUX_PORTING_COMMON Change to use RKP",
		"new_value, old_value, // SEC_SELINUX_PORTING_COMMON Change to use RKP",
		"selinuxfs.c sel_write_enforce audit args")
	# init_sel_fs(): selinux_enabled does not exist in this tree at all
	if "CONFIG_ALWAYS_ENFORCE" in src:
		src = resub(src,
			r"// \[ SEC_SELINUX_PORTING_COMMON\n#ifdef CONFIG_ALWAYS_ENFORCE\n"
			r"\tselinux_enabled = 1;\n#endif\n// \] SEC_SELINUX_PORTING_COMMON\n",
			"", "selinuxfs.c init_sel_fs enabled")
	return src


def net_hook(src):
	if "CONFIG_ALWAYS_ENFORCE" not in src:
		return src
	src = resub(src,
		r"// \[ SEC_SELINUX_PORTING_COMMON\n#ifdef CONFIG_ALWAYS_ENFORCE\n"
		r"\tselinux_enabled = 1;\n#endif\n// \] SEC_SELINUX_PORTING_COMMON\n",
		"", "net hook selinux_enabled")
	if "CONFIG_ALWAYS_ENFORCE" in src:
		sys.exit("error: net hook: ALWAYS_ENFORCE block remains")
	return src


def status_c(src):
	if "#ifdef CONFIG_ALWAYS_ENFORCE" not in src:
		return src
	return resub(src,
		r"#ifdef CONFIG_ALWAYS_ENFORCE\n\s*status->enforcing = 1;\n"
		r"#else\n(\s*status->enforcing = enforcing_enabled\(state\);\n)#endif\n",
		r"\1", "status.c enforcing")


def policydb_c(src):
	if "CONFIG_ALWAYS_ENFORCE" not in src:
		return src
	src = resub(src,
		r"#ifndef CONFIG_ALWAYS_ENFORCE\n\tpanic\(\"SELinux:Failed to [^\"]*\"\);\n"
		r"#endif /\*CONFIG_ALWAYS_ENFORCE\*/\n",
		"", "policydb.c panic", count=2)
	if "CONFIG_ALWAYS_ENFORCE" in src:
		sys.exit("error: policydb.c: ALWAYS_ENFORCE block remains")
	return src


# ---------------------------------------------------------------------------
# security/selinux/ss/services.c
# ---------------------------------------------------------------------------
def services_c(src):
	# 1. ss_initialized is a duplicate of state->initialized that only this
	#    tree sets; the merged flag is the one upstream checks.
	src = rep(src, "int ss_initialized;\n", "", "services.c ss_initialized definition")
	src = rep(src, "ss_initialized = 1;",
		"selinux_mark_initialized(&selinux_state);",
		"services.c ss_initialized store")
	if "ss_initialized" in src:
		src = re.sub(r"\bss_initialized\b",
			"selinux_initialized(&selinux_state)", src)
	if "ss_initialized" in src:
		sys.exit("error: services.c: ss_initialized references remain")

	# 2. Samsung force-enforcing glue.
	if "#ifdef CONFIG_ALWAYS_ENFORCE" in src:
		src = resub(src,
			r"#ifdef CONFIG_ALWAYS_ENFORCE\n\s*selinux_enforcing = 1;\n#endif\n",
			"", "services.c ALWAYS_ENFORCE glue", count=3)

	# 3. convert_context_handle_invalid_context() had the check inverted:
	#    it rejected invalid contexts when permissive instead of enforcing.
	#    Each anchor includes the following return statement because the two
	#    "return 0" call sites are otherwise identical.
	src = rep(src,
		"if (!selinux_enforcing) // SEC_SELINUX_PORTING_COMMON Change to use RKP\n"
		"\t\treturn -EINVAL;",
		"if (enforcing_enabled(state)) // SEC_SELINUX_PORTING_COMMON Change to use RKP\n"
		"\t\treturn -EINVAL;",
		"services.c invalid context check")
	src = rep(src,
		"if (!selinux_enforcing) // SEC_SELINUX_PORTING_COMMON Change to use RKP\n"
		"\t\treturn 0;\n"
		"// ] SEC_SELINUX_PORTING_COMMON\n"
		"\treturn -EPERM;",
		"if (!enforcing_enabled(state)) // SEC_SELINUX_PORTING_COMMON Change to use RKP\n"
		"\t\treturn 0;\n"
		"// ] SEC_SELINUX_PORTING_COMMON\n"
		"\treturn -EPERM;",
		"services.c validtrans permissive check")
	src = rep(src,
		"if (!selinux_enforcing) // SEC_SELINUX_PORTING_COMMON Change to use RKP \n"
		"\t\treturn 0;\n"
		"// ] SEC_SELINUX_PORTING_COMMON\n"
		"\treturn -EACCES;",
		"if (!enforcing_enabled(state)) // SEC_SELINUX_PORTING_COMMON Change to use RKP \n"
		"\t\treturn 0;\n"
		"// ] SEC_SELINUX_PORTING_COMMON\n"
		"\treturn -EACCES;",
		"services.c compute_sid permissive check")
	if "selinux_enforcing" in src:
		sys.exit("error: services.c: selinux_enforcing references remain")
	return src


# ---------------------------------------------------------------------------
# security/selinux/hooks.c
# ---------------------------------------------------------------------------
def hooks_c(src):
	# ss_initialized -> state->initialized, including the three call sites
	# the original commit leaves behind (inode revalidate, anon inode
	# security and inode_post_setxattr) which would stop the build once the
	# definition is gone.
	if "ss_initialized" in src:
		src = re.sub(r"\bss_initialized\b",
			"selinux_initialized(&selinux_state)", src)
	if "ss_initialized" in src:
		sys.exit("error: hooks.c: ss_initialized references remain")

	if "CONFIG_ALWAYS_ENFORCE" in src:
		# enforcing_setup(): keep the plain assignments, drop the forced arm
		src = resub(src,
			r"#ifdef CONFIG_ALWAYS_ENFORCE\n\s*selinux_enforcing_boot = 1;\n"
			r"\s*selinux_enforcing = 1;\n#else\n", "",
			"hooks.c enforcing_setup")
		src = rep(src,
			"\t\tselinux_enforcing = enforcing ? 1 : 0;\n#endif\n",
			"\t\tselinux_enforcing = enforcing ? 1 : 0;\n",
			"hooks.c enforcing_setup endif")

		# selinux_enabled_setup(): same, and selinux_enabled does not exist here
		src = resub(src,
			r"#ifdef CONFIG_ALWAYS_ENFORCE\n\s*selinux_enabled = 1;\n#else\n",
			"", "hooks.c selinux_enabled_setup")
		src = rep(src,
			"\t\tselinux_enabled = enabled ? 1 : 0;\n\t#endif\n",
			"\t\tselinux_enabled = enabled ? 1 : 0;\n",
			"hooks.c selinux_enabled_setup endif")

		# selinux_init() / selinux_nf_ip_init(): boot-time force-enforcing
		src = resub(src,
			r"// \[ SEC_SELINUX_PORTING_COMMON\n#ifdef CONFIG_ALWAYS_ENFORCE\n"
			r"\s*selinux_enforcing_boot = 1;\n#endif\n// \] SEC_SELINUX_PORTING_COMMON\n",
			"", "hooks.c selinux_init ALWAYS_ENFORCE")
		src = resub(src,
			r"// \[ SEC_SELINUX_PORTING_COMMON\n#ifdef CONFIG_ALWAYS_ENFORCE\n"
			r"\s*selinux_enabled = 1;\n#endif\n// \] SEC_SELINUX_PORTING_COMMON\n",
			"", "hooks.c nf_ip_init ALWAYS_ENFORCE")
	if "CONFIG_ALWAYS_ENFORCE" in src:
		sys.exit("error: hooks.c: ALWAYS_ENFORCE block remains")
	return src


patch("security/selinux/include/security.h", security_h)
patch("security/selinux/include/avc_ss.h", avc_ss_h)
patch("security/selinux/Makefile", selinux_makefile)
patch("security/selinux/selinuxfs.c", selinuxfs_c)
patch("security/selinux/netif.c", net_hook)
patch("security/selinux/netnode.c", net_hook)
patch("security/selinux/netport.c", net_hook)
patch("security/selinux/ss/status.c", status_c)
patch("security/selinux/ss/policydb.c", policydb_c)
patch("security/selinux/ss/services.c", services_c)
patch("security/selinux/hooks.c", hooks_c)
patch("kernel/audit.c", audit_c)
patch("fs/proc/Makefile", proc_makefile)
patch("fs/proc/Kconfig", proc_kconfig)

# CONFIG_PROC_AVC is gone from kconfig now, so it must not linger in any
# defconfig either (the generated one is exported by build.sh).
for cfg in sorted((root / "arch/arm64/configs").rglob("*defconfig")):
	text = cfg.read_text()
	out = re.sub(r"^CONFIG_PROC_AVC=y\n", "", text, flags=re.M)
	out = re.sub(r"^# CONFIG_PROC_AVC is not set\n", "", out, flags=re.M)
	if out != text:
		cfg.write_text(out)
		changed.append(str(cfg.relative_to(root)))

if changed:
	print("patched: " + ", ".join(changed))
else:
	print("already patched, nothing to do")
PY

# ---------------------------------------------------------------------------
# Post-conditions: a half-applied tree must never reach the compiler.
# ---------------------------------------------------------------------------
fails=0
check() {
	if eval "$2"; then
		echo "  ok: $1"
	else
		echo "  FAIL: $1" >&2
		fails=$((fails + 1))
	fi
}

check "ss_initialized is gone" \
	"! grep -rq 'ss_initialized' '$KROOT/security/selinux'"
check "state->initialized is marked on policy load" \
	"grep -q 'selinux_mark_initialized(&selinux_state);' '$KROOT/security/selinux/ss/services.c'"
check "enforcing flag lives in selinux_state" \
	"grep -q 'return state->enforcing;' '$KROOT/security/selinux/include/security.h'"
check "no ALWAYS_ENFORCE left" \
	"! grep -rq 'CONFIG_ALWAYS_ENFORCE' '$KROOT/security' '$KROOT/fs/proc'"
check "audit defaults to off" \
	"grep -q 'audit_default = AUDIT_OFF;' '$KROOT/kernel/audit.c'"
check "proc_avc is not built" \
	"! grep -q '^proc-.*+= proc_avc.o' '$KROOT/fs/proc/Makefile'"
check "proc_avc kconfig stanza is gone" \
	"! grep -q '^config PROC_AVC' '$KROOT/fs/proc/Kconfig'"
check "no defconfig still selects PROC_AVC" \
	"! grep -rq 'CONFIG_PROC_AVC=y' '$KROOT/arch/arm64/configs'"

[ "$fails" -eq 0 ] || { echo "error: $fails post-condition(s) failed" >&2; exit 1; }
echo "SELinux policy switching patched successfully"
