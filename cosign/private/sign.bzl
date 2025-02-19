"Implementation details for sign rule"

_DOC = """Sign an oci_image using cosign binary at a remote registry.

It signs the image by its digest determined beforehand.

```starlark
oci_image(
    name = "image"
)

cosign_sign(
    name = "sign",
    image = ":image",
    repository = "index.docker.io/org/image"
)
```

`repository` attribute can be overridden using the `--repository` flag.

```starlark
oci_image(
    name = "image"
)

cosign_sign(
    name = "sign",
    image = ":image",
    repository = "index.docker.io/org/image"
)
```

run `bazel run :sign -- --repository=index.docker.io/org/test`
"""

_attrs = {
    "image": attr.label(allow_single_file = True, mandatory = True, doc = "Label to an oci_image"),
    "repository": attr.string(mandatory = True, doc = """\
        Repository URL where the image will be signed at, e.g.: `index.docker.io/<user>/image`.
        Digests and tags are not allowed.
    """),
    "_sign_sh_tpl": attr.label(default = "sign.sh.tpl", allow_single_file = True),
}

def _cosign_sign_impl(ctx):
    cosign = ctx.toolchains["@contrib_rules_oci//cosign:toolchain_type"]
    yq = ctx.toolchains["@aspect_bazel_lib//lib:yq_toolchain_type"]

    if ctx.attr.repository.find(":") != -1 or ctx.attr.repository.find("@") != -1:
        fail("repository attribute should not contain digest or tag.")

    executable = ctx.actions.declare_file("cosign_sign_{}.sh".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._sign_sh_tpl,
        output = executable,
        is_executable = True,
        substitutions = {
            "{{cosign_path}}": cosign.cosign_info.binary.short_path,
            "{{yq_path}}": yq.yqinfo.bin.short_path,
            "{{image_dir}}": ctx.file.image.short_path,
            "{{fixed_args}}": " ".join(["--repository", ctx.attr.repository]),
        },
    )

    runfiles = ctx.runfiles(files = [ctx.file.image])
    runfiles = runfiles.merge(yq.default.default_runfiles)
    runfiles = runfiles.merge(cosign.default.default_runfiles)

    return DefaultInfo(executable = executable, runfiles = runfiles)

cosign_sign = rule(
    implementation = _cosign_sign_impl,
    attrs = _attrs,
    doc = _DOC,
    executable = True,
    toolchains = [
        "@contrib_rules_oci//cosign:toolchain_type",
        "@aspect_bazel_lib//lib:yq_toolchain_type",
    ],
)
