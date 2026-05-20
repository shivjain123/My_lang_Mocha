# Run once as admin to set up MochaLang code signing certificate
$cert = New-SelfSignedCertificate -Subject "CN=MochaLang" -CertStoreLocation "Cert:\LocalMachine\My" -KeyUsage DigitalSignature -Type CodeSigningCert

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
$store.Open("ReadWrite")
$store.Add($cert)
$store.Close()

$store2 = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPublisher", "LocalMachine")
$store2.Open("ReadWrite")
$store2.Add($cert)
$store2.Close()

Write-Host "✅ MochaLang certificate installed! All compiled executables will now be signed automatically."