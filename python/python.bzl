# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

WheelInfo = provider(
    fields = {
        "distribution": "distribution (string)",
        "version": "version (string)",
        "size": "size of the wheel in bytes (int)",
    },
)

def py_library(*args, **kwargs):
  """See the Bazel core py_library documentation.

  [available here](
  https://docs.bazel.build/versions/master/be/python.html#py_library).
  """
  native.py_library(*args, **kwargs)

def py_binary(*args, **kwargs):
  """See the Bazel core py_binary documentation.

  [available here](
  https://docs.bazel.build/versions/master/be/python.html#py_binary).
  """
  native.py_binary(*args, **kwargs)

def py_test(*args, **kwargs):
  """See the Bazel core py_test documentation.

  [available here](
  https://docs.bazel.build/versions/master/be/python.html#py_test).
  """
  native.py_test(*args, **kwargs)

def _extract_wheel_impl(ctx):
    d = ctx.actions.declare_directory("extracted")
    command = ["BUILDDIR=$(pwd)"]
    command += ["%s extract --whl=%s --directory=%s" % (ctx.executable._piptool.path, ctx.file.wheel.path, d.path)]
    inputs = [ctx.file.wheel]
    outputs = [d]
    tools = [ctx.executable._piptool]

    command += ["cd %s" % d.path]
    for patchfile in ctx.files.patches:
        command += ["{patchtool} {patch_args} < $BUILDDIR/{patchfile}".format(
            patchtool = ctx.attr.patch_tool,
            patchfile = patchfile.path,
            patch_args = " ".join([
                "'%s'" % arg
                for arg in ctx.attr.patch_args
            ]),
        )]
        inputs += [patchfile]

    command += ctx.attr.patch_cmds

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = outputs,
        tools = tools,
        command = " && ".join(command),
        mnemonic = "ExtractWheel",
        execution_requirements = {"no-remote": "1"}
    )

    return [
        DefaultInfo(
            files = depset(direct = outputs),
            runfiles = ctx.runfiles(files = [d]),
        ),
        WheelInfo(
            distribution = ctx.attr.distribution,
            version = ctx.attr.version,
            size = ctx.attr.wheel_size,
        ),
        PyInfo(
            transitive_sources = depset(direct=[d]),
            has_py2_only_sources = ctx.attr.python_version == "PY2",
            has_py3_only_sources = ctx.attr.python_version == "PY3",
        ),
    ]

extract_wheel = rule(
    implementation = _extract_wheel_impl,
    attrs = {
        "wheel": attr.label(
            doc = "A wheel to extract.",
            allow_single_file = [".whl"],
        ),
        "deps": attr.label_list(default = []),
        "patches": attr.label_list(default = [], allow_files=True),
        "patch_tool": attr.string(default = "patch"),
        "patch_args": attr.string_list(default = ["-p0"]),
        "patch_cmds": attr.string_list(default = []),
        "distribution": attr.string(),
        "version": attr.string(),
        "wheel_size": attr.int(doc = "wheel size in bytes"),
        "python_version": attr.string(values = ["PY2", "PY3", ""]),
        "_piptool": attr.label(
            allow_files = True,
            executable = True,
            default = Label("//tools:piptool.par"),
            cfg = "host",
        ),
    },
)
