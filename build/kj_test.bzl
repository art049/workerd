def kj_test(
        src,
        data = [],
        deps = [],
        tags = [],
        size = "medium",
        **kwargs):
    test_name = src.removesuffix(".c++")

    # Create wrapper source file that will inject autogate initialization based on environment variable
    wrapper_name = test_name + "_autogate_wrapper"
    wrapper_file = wrapper_name + ".c++"

    native.genrule(
        name = wrapper_name + "_gen",
        outs = [wrapper_file],
        cmd = """
cat > $@ << 'EOF'
// Auto-generated wrapper to initialize autogates based on environment variable
#include <workerd/util/autogate.h>
#include <cstdlib>
#include <cstring>

__attribute__((constructor))
static void autogate_initializer() {
  if (getenv("WORKERD_ALL_AUTOGATES") != nullptr) {
    workerd::util::Autogate::initAllAutogates();
  } else {
    workerd::util::Autogate::initAutogate({});
  }
}
EOF
""",
    )

    def run_test(name, env = {}):
        # merged_env = list(env)
        # if "env" in kwargs:
        #     merged_env.extend(kwargs.pop("env"))

        native.cc_test(
            name = name,
            srcs = [src, wrapper_file],
            deps = [
                "@capnp-cpp//src/kj:kj-test",
                "//src/workerd/util:autogate",
            ] + deps,
            linkopts = select({
                "@//:use_dead_strip": ["-Wl,-dead_strip", "-Wl,-no_exported_symbols"],
                "//conditions:default": [""],
            }),
            data = data,
            tags = tags,
            size = size,
            env = env,
            **kwargs
        )

    run_test(name = test_name)
    run_test(name = test_name + "@all-autogates", env = {"WORKERD_ALL_AUTOGATES": "1"})
