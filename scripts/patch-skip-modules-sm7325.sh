F=kernel/module.c
SKIP_LIST='blk_sec_stats,ssg_iosched'   # use '*' to skip every module by name

# 0) remove my earlier SKIP_BUILTIN_MODS block if it was applied
sed -i '/SKIP_BUILTIN_MODS/,/^\t}$/d' $F

if ! grep -q "MODULE_SKIP_BEGIN" $F; then
cat > /tmp/skip_block.c <<'EOF'

/* MODULE_SKIP_BEGIN */
#ifndef MODULE_SKIP_DEFAULT
#define MODULE_SKIP_DEFAULT ""
#endif
#ifndef MODULE_SKIP_MISMATCH_DEFAULT
#define MODULE_SKIP_MISMATCH_DEFAULT true
#endif
static char *module_skip = MODULE_SKIP_DEFAULT;
static bool module_skip_mismatch = MODULE_SKIP_MISMATCH_DEFAULT;
core_param(module_skip, module_skip, charp, 0400);
core_param(module_skip_mismatch, module_skip_mismatch, bool, 0400);

/* '-' and '_' are equivalent in module names */
static bool mod_str_eq(const char *a, const char *b, size_t n)
{
	while (n--) {
		char x = *a++, y = *b++;

		if (x == '-')
			x = '_';
		if (y == '-')
			y = '_';
		if (x != y)
			return false;
	}
	return true;
}

static bool mod_pat_match(const char *pat, size_t plen, const char *name)
{
	size_t nlen = strlen(name);

	if (plen > 3 && !memcmp(pat + plen - 3, ".ko", 3))
		plen -= 3;
	if (!plen)
		return false;
	if (plen && pat[plen - 1] == '*') {		/* prefix* or "*" */
		plen--;
		return nlen >= plen && mod_str_eq(pat, name, plen);
	}
	if (pat[0] == '*') {				/* *suffix */
		pat++;
		plen--;
		return nlen >= plen && mod_str_eq(pat, name + nlen - plen, plen);
	}
	return nlen == plen && mod_str_eq(pat, name, plen);
}

/* module_skip is a comma-separated list of names / patterns */
static bool module_skipped(const char *name)
{
	const char *p;
	size_t len;

	if (!name || !module_skip)
		return false;

	for (p = module_skip; *p; p += len) {
		len = strcspn(p, ",");
		if (mod_pat_match(p, len, name))
			return true;
		if (p[len] == ',')
			len++;
	}
	return false;
}
/* MODULE_SKIP_END */
EOF
cat > /tmp/skip_call.c <<'EOF'
	/* MODULE_SKIP_CALL: built-in / unwanted modules succeed silently */
	if (module_skipped(info->name)) {
		pr_info("%s: skipped by module_skip\n", info->name);
		err = 0;
		goto free_copy;
	}

EOF
cat > /tmp/skip_wrap.c <<'EOF'
/* MODULE_SKIP_WRAP: stale/mismatched .ko (module_layout, vermagic, CRC) */
static int load_module(struct load_info *info, const char __user *uargs,
		       int flags)
{
	int err = __load_module(info, uargs, flags);

	if (err == -ENOEXEC && module_skip_mismatch) {
		pr_warn("module load failed with -ENOEXEC (see message above), ignoring\n");
		return 0;
	}
	return err;
}

EOF
awk '
/^core_param\(module_blacklist, module_blacklist, charp, 0400\);/ {
  print; while ((getline l < "/tmp/skip_block.c") > 0) print l; next }
/^\tif \(blacklisted\(info->name\)\) \{/ {
  while ((getline l < "/tmp/skip_call.c") > 0) print l; print; next }
/^static int load_module\(struct load_info \*info, const char __user \*uargs,$/ {
  print "static int __load_module(struct load_info *info, const char __user *uargs,"; next }
/^SYSCALL_DEFINE3\(init_module,/ {
  while ((getline l < "/tmp/skip_wrap.c") > 0) print l; print; next }
{ print }' $F > $F.new && mv $F.new $F
fi

# set the compile-time default list
sed -i "s|^#define MODULE_SKIP_DEFAULT .*|#define MODULE_SKIP_DEFAULT \"$SKIP_LIST\"|" $F

# verify all 4 anchors applied (expect 5+ hits)
grep -n "MODULE_SKIP_BEGIN\|MODULE_SKIP_CALL\|MODULE_SKIP_WRAP\|__load_module\|MODULE_SKIP_DEFAULT \"" $F