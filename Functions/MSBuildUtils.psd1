@{
    ModuleVersion = '1.0'
    GUID = '12345678-1234-5678-1234-567812345678'
    Author = 'CommentAnalyzer Team'
    CompanyName = 'CommentAnalyzer'
    Copyright = '(c) 2024 CommentAnalyzer. All rights reserved.'
    Description = 'MSBuild工具函数模块'
    PowerShellVersion = '5.0'
    FunctionsToExport = @('Get-LatestMsBuildPath')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('MSBuild', 'Build', 'Tools')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = ''
            ReleaseNotes = '初始版本'
        }
    }
} 