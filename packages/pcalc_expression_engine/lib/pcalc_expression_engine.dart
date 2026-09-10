export 'src/backend.dart'
    show
        BackendCapabilities,
        BackendKind,
        ExpressionEvaluationResult,
        ExpressionBackend,
        ExpressionEngineInfo,
        ExpressionValueKind,
        ExpressionSession,
        createExpressionSession,
        backendDebugLoggingEnabled,
        clangLanguage,
        getLastErrorMessage,
        initializeTinyExpr,
        selectedBackendInfo,
        resetExpressionSession,
        setBackendPreference,
        setClangLanguage,
        setBackendDebugLoggingEnabled;

export 'package:dart_clang_constexpr/dart_clang_constexpr.dart'
    show ClangExpressionLanguage, selectableClangExpressionLanguages;

export 'src/backend_probe.dart'
    show canUseClangConstexpr, canUseCling, canUseRoot;
export 'src/engine.dart' show evaluateExpression;
