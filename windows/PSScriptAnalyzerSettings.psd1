# Regras do PSScriptAnalyzer pro profile. As de estilo ficam de fora:
# num profile pessoal os atalhos curtos (gs, gac, _ok…) são o objetivo,
# não "Verb-Noun"; e as variáveis globais são a configuração.
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSUseApprovedVerbs',
        'PSAvoidGlobalVars',
        'PSUseSingularNouns',
        'PSAvoidUsingWriteHost',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingInvokeExpression',        # zoxide init: é o jeito oficial
        'PSUseBOMForUnicodeEncodedFile',
        'PSReviewUnusedParameter',
        'PSAvoidAssignmentToAutomaticVariable',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidOverwritingBuiltInCmdlets',
        'PSUseCompatibleCmdlets',
        'PSAvoidUsingCmdletAliases'            # gc, gl, gp… aqui são as NOSSAS funções (os aliases saem no começo)
    )
}
