# Copyright 2016 The Sysl Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License."""Super smart code writer."""

# TODO: Add no_except param to sysl_model.

VALID_SERIALIZERS = set(['json_in', 'json_out', 'xml_in', 'xml_out'])


def _inouts(prefix, serializers):
  if serializers == None:
    serializers = ["*_*"]

  inouts = []
  for s in serializers or []:
    (fmt, dirn) = s.split('_')
    fmts = ['json', 'xml'] if fmt == '*' else [fmt]
    dirns = ['in', 'out'] if dirn == '*' else [dirn]
    for fmt in fmts:
      for dirn in dirns:
        inouts.append(fmt + "_" + dirn)
  bogus_serializers = [
    s for s in inouts
    if s not in VALID_SERIALIZERS]
  if bogus_serializers:
    fail("invalid serializers: " + bogus_serializers, attr="serializer")

  files = (
    ([prefix + "JsonDeserializer.java"] if 'json_in' in inouts else []) +
    ([prefix + "JsonSerializer.java"] if 'json_out' in inouts else []) +
    ([prefix + "XmlDeserializer.java"] if 'xml_in' in inouts else []) +
    ([prefix + "XmlSerializer.java"] if 'xml_out' in inouts else [])
  )
  return (inouts, files)


def sysl_model(
    name, srcs, root, module, app, entities, package,
    deps=None,
    serializers=None,  # <xml|json|*>_<in|out|*>
    visibility=None):
  outpath = package.replace(".", "/") + "/"
  prefix = outpath + app

  (inouts, serializer_files) = _inouts(prefix, serializers)

  _sysl_tool(
    name = name,
    tool = "model",
    srcs = srcs,
    root = root,
    module = module,
    app = app,
    package = package,
    entities = entities,
    jar = True,
    outs = (
      [
        prefix + ".java",
        prefix + "Exception.java",
      ] +
      serializer_files +
      [outpath + e + ".java" for e in entities]
    ),
    deps = [
      "//external:sysl_io_java",
      "@org_apache_commons_commons_lang3//jar",
      "@com_fasterxml_jackson_core_jackson_core//jar",
      "@com_fasterxml_jackson_core_jackson_databind//jar",
      "@joda_time_joda_time//jar",
    ] + (deps or []),
    flags = [
      '--serializers=' + ','.join(inouts),
    ],
    visibility = visibility,
  )


def sysl_facade(name, srcs, root, module, app, model, package,
    serializers=None,  # <xml|json|*>_<in|out|*>
    visibility=None):
  outpath = package.replace(".", "/") + "/"
  prefix = outpath + app

  (inouts, serializer_files) = _inouts(prefix, serializers)

  _sysl_tool(
    name = name,
    tool = "facade",
    srcs = srcs,
    root = root,
    module = module,
    app = app,
    package = package,
    outs = [prefix + ".java"] + serializer_files,
    deps = [
      "@com_fasterxml_jackson_core_jackson_core//jar",
      "@com_fasterxml_jackson_core_jackson_databind//jar",
      "//external:sysl_io_java",
      "@joda_time_joda_time//jar",
      "@org_apache_commons_commons_lang3//jar",
      model
    ],
    flags = [
      '--serializers=' + ','.join(inouts),
    ],
    jar = True,
    visibility = visibility,
  )


def sysl_xsd(name, srcs, root, module, app, visibility=None):
  _sysl_tool(
    name = name,
    tool = "xsd",
    srcs = srcs,
    root = root,
    module = module,
    app = app,
    package = '',
    outs = [app + ".xsd"],
    visibility = visibility,
  )


def sysl_swagger(name, srcs, root, module, app, package,
    outbase=None,
    visibility=None):
  _sysl_tool(
    name = name,
    tool = "swagger",
    srcs = srcs,
    root = root,
    module = module,
    app = app,
    package = package,
    outs = [app.replace(' :: ', '_').replace(' ', '') + ".swagger.yaml"],
    visibility = visibility,
  )


def sysl_spring_rest_service(name, srcs, root, module, app, package,
    entities=None,
    outbase=None,
    visibility=None):
  entities = entities or []
  outpath = package.replace(".", "/") + "/"

  _sysl_tool(
    name = name,
    tool = "spring-rest-service",
    srcs = srcs,
    root = root,
    module = module,
    app = app,
    package = package,
    entities = entities,
    jar = True,
    outs = [
      outpath + app + "Controller.java",
    ] + [outpath + e + ".java" for e in entities],
    deps = [
      "@io_swagger_swagger_annotations//jar",
      "@org_projectlombok_lombok//jar",
      "@org_springframework_spring_beans//jar",
      "@org_springframework_spring_web//jar",
    ],
    visibility = visibility,
  )


# private

def _sysl_tool(
    name, tool, srcs, root, module, app, package,
    entities=None,
    jar=False,
    outs=None,
    deps=None,
    flags=None,
    visibility=None):

  if entities:
    native.filegroup(
      name = name + "_entities",
      srcs = outs,
      visibility = visibility,
    )
  else:
    entities = []

  native.genrule(
    name = name + "_dummy",
    outs = ["." + name + "_dummy"],
    cmd = "touch '$@'",
  )

  native.genrule(
    name = name + "_java" if jar else name,
    srcs = srcs + [":" + name + "_dummy"],
    outs = outs,
    cmd = " ".join([
        "$(location //external:sysl_reljam)",
        "--root '%s'" % root,
        "--out '$(location :%s_dummy)/..'" % name,
        "--package '%s'" % package,
      ] + (["--entities '%s'" % ','.join(entities)] if entities else []) +
      (flags or []) + [
        tool,
        "'%s'" % module,
        "'%s'" % app,
      ]),
    tools = ["//external:sysl_reljam"],
    visibility = visibility,
  )

  if jar:
    native.java_library(
      name = name,
      srcs = outs + ([name + "_entities"] if entities else []),
      deps = deps or [],
      visibility = visibility,
    )


def sysl_repositories(
  maven_settings_file=None,
  maven_url=None,
  ):

  _sysl_repositories(
    sysl_workspace = "@com_github_anz_bank_sysl",
    maven_settings_file = maven_settings_file,
    maven_url = maven_url,
  )


def internal_sysl_repositories(
  maven_settings_file=None,
  maven_url=None,
  ):

  _sysl_repositories(
    sysl_workspace = "",
    maven_settings_file = maven_settings_file,
    maven_url = maven_url,
  )

def _sysl_repositories(
  sysl_workspace,
  maven_settings_file=None,
  maven_url=None,
  ):

  native.maven_server(
    name='sysl_maven_server',
    settings_file=maven_settings_file,
    url=maven_url,
  )

  native.maven_jar(
    name = "com_fasterxml_jackson_core_jackson_core",
    artifact = "com.fasterxml.jackson.core:jackson-core:2.8.5",
    sha1 = "60d059f5d2930ccd1ef03535b713fd9f933d1ba7",
    server = "sysl_maven_server",
  )

  native.maven_jar(
    name = "com_fasterxml_jackson_core_jackson_databind",
    artifact = "com.fasterxml.jackson.core:jackson-databind:2.8.5",
    sha1 = "b3035f37e674c04dafe36a660c3815cc59f764e2",
    server = "sysl_maven_server",
  )

  native.maven_jar(
    name = "io_swagger_swagger_annotations",
    artifact = "io.swagger:swagger-annotations:1.5.12",
    sha1 = "c7ec660163f3680e8afe2aacf2a14d27d7dcc509",
    server = "sysl_maven_server",
  )

  native.maven_jar(
    name = "joda_time_joda_time",
    artifact = "joda-time:joda-time:2.9.6",
    sha1 = "e370a92153bf66da17549ecc78c69ec6c6ec9f41",
    server = "sysl_maven_server",
  )

  native.maven_jar(
    name = "org_apache_commons_commons_lang3",
    artifact = "org.apache.commons:commons-lang3:3.5",
    sha1 = "6c6c702c89bfff3cd9e80b04d668c5e190d588c6",
    server = "sysl_maven_server",
  )

  native.maven_jar(
    name = "org_projectlombok_lombok",
    artifact = "org.projectlombok:lombok:1.16.12",
    sha1 = "64b2d2e8734b54ddba60a69df68a6dac627366c8",
    server = "sysl_maven_server",
  )

  native.maven_jar(
    name = "org_springframework_spring_beans",
    artifact = "org.springframework:spring-beans:4.2.9.RELEASE",
    sha1 = "2b9b6ebb4271c61e307f4eae8e00ccec23891440",
    server = "sysl_maven_server",
  )

  native.maven_jar(
    name = "org_springframework_spring_web",
    artifact = "org.springframework:spring-web:4.2.9.RELEASE",
    sha1 = "16cc1e5c3db699f71ef8596d63c961b9c6ed0d1d",
    server = "sysl_maven_server",
  )

  native.git_repository(
    name = "org_pubref_rules_protobuf",
    remote = "https://github.com/pubref/rules_protobuf",
    tag = "v0.7.1",
  )

  # TODO
  # native.load(
  #   "@org_pubref_rules_protobuf//python:rules.bzl",
  #   "py_proto_repositories",
  # )
  # native.py_proto_repositories()

  native.bind(
    name = "sysl_reljam",
    actual = sysl_workspace + "//src/exporters:reljam",
  )

  native.bind(
    name = "sysl_io_java",
    actual = sysl_workspace + "//java/io/sysl",
  )
