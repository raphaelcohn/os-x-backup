# PIV

* Personal Identity Verification
* NIST SP 800-73 / FIPS 201
* Sometimes called HSPD-12 PIV smart card


# FIDO2

* Encompasses
	* WebAuthn (a W3C standard) for authenticators
	* CTAP (Client to Authentication Protocol)
	* Extends FIDO U2F
* Websites store a public key with a credential ID
	* These are at least 16 bytes, with 100 bits of entropy (so GUID-like), and ideally should be random
	* For a near stateless authenticator, an encrypted public key of the authenticator's choosing, such that when presented to the authenticator, it can identify it
		* This allows authenticators to store only one private key for all uses, eg if using retinal id
* Resident keys explanation: <https://duo.com/labs/tech-notes/resident-keys-and-the-future-of-webauthn-fido2>
* Suitable for website logins as a replacement for passwords
* If using resident keys, also as a replacement for user names
* It seems a credential (looking at libfido2 / <https://developers.yubico.com/libfido2/Manuals/fido_cred_aaguid_len.html>) can contain a X509 certificate.
* User id, user name, user display name and user icon are all optional

* What are protections?
* What is largeBlobKey?
	* A 32-byte symmetric key associated with the generated credential.
	* Seems to be 




## Usages

* Local Linux logon via PAM
	* <https://support.yubico.com/hc/en-us/articles/360016649099-Ubuntu-Linux-Login-Guide-U2F>
* OpenSSH 8.2+
* Password-less web logins
* Username-less web logins using Resident Keys



## API

* A new key-pair is generated as follows
	* `challenge`: A challenge of random bytes from a server, to defeat replay attacks; sometimes called client data hash
	* `rp`: Relying Party, a domain name (the same as or a subset of the website) and an associated organization nane
	* `user`: An identifier as an array of bytes, with optional additional details like user's email address
	* `pubKeyCredParams`: `[{alg: -7, type: "public-key"}]`; an array of acceptable public key parameters
		* See [CBOR Object Signing and Encryption (COSE) Algorithm Numbers for the meaning of alg](https://www.iana.org/assignments/cose/cose.xhtml#algorithms)
		* We would only want to use `-8` (EdDSA)
		* We should probably also specify the `kty` and `crv` fields (the latter to ensure use with 25519 rather than 448)
	* Problem: we can not easily control if attestation data is used in `direct` mode (rather than `none` or `indirect`)
* Attestation
	* This reveals a GUID, known as the AAGUID, which is the same for a combination of firmware revision and model of a security key
		* eg <https://support.yubico.com/hc/en-us/articles/360016648959-YubiKey-Hardware-FIDO2-AAGUIDs>
	* As such, it can be used to identify known threats by a hacker of a website for a particular kind of key
	* Attestations can be verified as long as one knows the `challenge` and `rp`
	* Are a signed message; the message being signed includes `rp`, flags, `AAGUID`, the Credential ID and the Credential Public key (in DER format)
	* The signer may or may not be the authenticator itself


# YubiKey Guide

* <https://github.com/drduh/YubiKey-Guide>


# Using a YuibKey 5 for OpenSSH

OpenSSH supports 3 different ways of using hardware security keys (see <https://callanbryant.co.uk/blog/how-to-get-the-best-out-of-your-yubikey-with-gpg/#general-yubikey-settings>).

* OpenPGP Smart Card with gnupg version 2 as a ssh-agent replacement
	* `gpg --export-ssh-key` exports a public key
	* Using gpg with SSH (but without a smart card) <https://opensource.com/article/19/4/gpg-subkeys-ssh>
* PIV (Private Identity Verification) smart card
	* OpenSC using slot 9a
	* OpenSC has had a LOT of CVEs over the years
* FIDO2 using OpenSSH 8.2+
	* Requires server support
	* rsync.net supports 8.2, but OS X standard ssh is 7.9
	* See <https://www.stavros.io/posts/u2f-fido2-with-ssh/>
	* We would want to use non-resident keys unless using resident keys is advantageous
		* Not sure how
	* Supported by github https://github.blog/2021-05-10-security-keys-supported-ssh-git-operations/
	* Can still be used with SSH certificates

Agent forwarding using GPG is painful (<https://callanbryant.co.uk/blog/how-to-get-the-best-out-of-your-yubikey-with-gpg/#gpg-agent-forwarding>) and brittle.


# Using Subkeys without a Master

* <https://alexcabal.com/creating-the-perfect-gpg-keypair>


# Git and GitHub code signing

* <https://callanbryant.co.uk/blog/how-to-get-the-best-out-of-your-yubikey-with-gpg/#configuration-for-code-signing>
* smimesign to use X.509 rather than PGP:-
	* <https://github.com/github/smimesign>
	* <https://docs.github.com/en/github/authenticating-to-github/managing-commit-signature-verification/telling-git-about-your-signing-key>
	* Works with Yubikey via Keychain Access on macOS
		* Uses PIV Smart Card
		* Need brew cask OpenSC (not brew install)
		* Need Yubikey PIV Manager / Yubikey PIV Tool
		* Need Keychain Access


# PKI / X.509

* Use a PIV smart card


# OS X code signing

* Uses a PIV smart card


# With a local password store (Linux / OS X)

* GPG + [pass](https://www.passwordstore.org/)
* pass is written in bash
* pass can be securely backed up to git (although that would expose a history of passwords)
* pass can be backed up to rsync.net, too, without git.
* Can be used for git credentials
* Go GUI client
* Firefox and Chrome plugins

