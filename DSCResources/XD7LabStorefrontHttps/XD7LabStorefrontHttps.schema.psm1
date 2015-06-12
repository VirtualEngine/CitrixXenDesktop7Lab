configuration XD7LabStorefrontHttps {
    param (
        ## Citrix XenDesktop installation source root
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $XenDesktopMediaPath,
        ## Personal information exchange (Pfx) ertificate file path
        [Parameter(Mandatory)] [System.String] $PfxCertificatePath,
        ## Pfx certificate thumbprint
        [Parameter(Mandatory)] [System.String] $PfxCertificateThumbprint,
        ## Pfx certificate password
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential] $PfxCertificateCredential,
        ## XenDesktop controller address for Director connectivity
        [Parameter(Mandatory)] [System.String[]] $ControllerAddress
    )

    Import-DscResource -ModuleName CitrixXenDesktop7, xWebAdministration, cPfxCertificate;

    $features = @(
        'NET-Framework-45-ASPNET',
        'Web-Server',
        'Web-Common-Http',
        'Web-Default-Doc',
        'Web-Http-Errors',
        'Web-Static-Content',
        'Web-Http-Redirect',
        'Web-Http-Logging',
        'Web-Filtering',
        'Web-Basic-Auth',
        'Web-Windows-Auth',
        'Web-Net-Ext45',
        'Web-AppInit',
        'Web-Asp-Net45',
        'Web-ISAPI-Ext',
        'Web-ISAPI-Filter',
        'Web-Mgmt-Console',
        'Web-Scripting-Tools'
    )
    foreach ($feature in $features) {
        WindowsFeature $feature {
            Name = $feature;
            Ensure = 'Present';
        }
    }

    cXD7Feature XD7StoreFront {
        Role = 'Storefront';
        SourcePath = $XenDesktopMediaPath;
        DependsOn = '[WindowsFeature]Web-Server';
    }

    cXD7Feature XD7Director {
        Role = 'Director';
        SourcePath = $XenDesktopMediaPath;#
        DependsOn = '[WindowsFeature]Web-Server';
    }

    foreach ($controller in $ControllerAddress) {
        xWebConfigKeyValue "ServiceAutoDiscovery_$controller" {
            ConfigSection = 'AppSettings';
            Key = 'Service.AutoDiscoveryAddresses';
            Value = $controller;
            IsAttribute = $false;
            WebsitePath = 'IIS:\Sites\Default Web Site\Director';
            DependsOn = '[WindowsFeature]Web-Server','[cXD7Feature]XD7Director';
        }
    }

    $filename = [System.IO.Path]::GetFileName($PfxCertificatePath);
    $destinationFilePath = Join-Path -Path "$env:SystemDrive\Source" -ChildPath $filename;
        
    File SSLCert {
        DestinationPath = $destinationFilePath;
        SourcePath = $PfxCertificatePath;
        Type = 'File';
    }

    cPfxCertificate "PfxCertificate_$filename" {
        Thumbprint = $PfxCertificateThumbprint;
        Location = 'LocalMachine';
        Store = 'My';
        Path = $destinationFilePath
        Credential = $PfxCertificateCredential;
        DependsOn = '[File]SSLCert';
    }

    xWebSite DefaultWebSite {
        Name = 'Default Web Site';
        PhysicalPath = 'C:\inetpub\wwwroot';
        BindingInfo = @(
            MSFT_xWebBindingInformation  { Protocol = 'HTTPS'; Port = 443; CertificateThumbprint = $PfxCertificateThumbprint; CertificateStoreName = 'My'; }
            MSFT_xWebBindingInformation  { Protocol = 'HTTP'; Port = 80; }
        )
        DependsOn = '[WindowsFeature]Web-Server',"[cPfxCertificate]PfxCertificate_$filename";
    }
}