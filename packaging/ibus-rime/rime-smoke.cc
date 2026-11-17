#include <rime_api.h>
#include <cstdio>
#include <cstring>
#include <initializer_list>

int main(int argc, char** argv) {
  if (argc != 3) return 2;
  RIME_STRUCT(RimeTraits, traits);
  traits.shared_data_dir = argv[1];
  traits.user_data_dir = argv[2];
  traits.app_name = "rime.arm64-smoke";
  traits.log_dir = "";
  RimeApi* api = rime_get_api();
  api->setup(&traits);
  api->initialize(&traits);
  for (const char* name : {"lua", "octagram", "charcode"}) {
    if (!api->find_module(name)) {
      std::fprintf(stderr, "Missing plugin: %s\n", name);
      return 3;
    }
  }
  api->start_maintenance(True);
  api->join_maintenance_thread();
  const auto session = api->create_session();
  if (!session || !api->select_schema(session, "smoke")) return 4;
  api->set_option(session, "ascii_mode", False);
  api->simulate_key_sequence(session, "test");
  RIME_STRUCT(RimeContext, context);
  if (!api->get_context(session, &context)) return 5;
  bool found = false;
  for (int i = 0; i < context.menu.num_candidates; ++i) {
    if (std::strcmp(context.menu.candidates[i].text, "中文测试") == 0) {
      found = api->select_candidate(session, i);
      break;
    }
  }
  api->free_context(&context);
  if (!found) return 6;
  RIME_STRUCT(RimeCommit, commit);
  if (!api->get_commit(session, &commit)) return 7;
  const bool correct = commit.text && std::strcmp(commit.text, "中文测试") == 0;
  api->free_commit(&commit);
  api->destroy_session(session);
  api->finalize();
  if (!correct) return 8;
  std::puts("PASS: Lua generated Chinese candidate and committed it; all three plugins registered");
}
