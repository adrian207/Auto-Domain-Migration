Import-Module Pester

Describe 'Server Migration Repository' {
    It 'has required Ansible playbooks' {
        $playbooks = Get-ChildItem -Path ../../ansible/playbooks -Filter '*.yml' | Select-Object -ExpandProperty Name
        $expected = '00_discovery.yml','01_prerequisites.yml','02_replication.yml','03_cutover.yml','04_validation.yml','99_rollback.yml','master_migration.yml'
        foreach ($file in $expected) {
            $playbooks | Should -Contain $file
        }
    }

    It 'has server migration roles' {
        $roles = Get-ChildItem -Path ../../ansible/roles -Directory | Select-Object -ExpandProperty Name
        $roles | Should -Contain 'server_discovery'
        $roles | Should -Contain 'server_prerequisites'
        $roles | Should -Contain 'server_replication'
        $roles | Should -Contain 'server_cutover'
        $roles | Should -Contain 'server_validation'
        $roles | Should -Contain 'server_rollback'
    }
}
