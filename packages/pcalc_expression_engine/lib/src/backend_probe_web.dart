bool get canUseRoot => false;

bool get canUseCling => false;

// The packaged Emscripten evaluator is available in every supported browser.
bool get canUseClangConstexpr => true;
