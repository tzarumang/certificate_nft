module certificate_nft::certificate {
    use sui::object::UID;
    use std::string::String;
    use sui::clock::Clock;

    // Error codes
    const ENotAuthorized: u64 = 1;

    // Certificate struct - this is the NFT
    public struct Certificate has key {
        id: UID,
        name: String,
        description: String,
        image_url: String,
        recipient: address,
        issuer: address,
        issue_date: u64,
        certificate_type: String,
        metadata: String, // JSON string for additional data
    }

    // Capability for issuing certificates
    public struct IssuerCap has key {
        id: UID,
        issuer_name: String,
        issuer_address: address,
    }

    // Admin capability for creating new issuers
    public struct AdminCap has key {
        id: UID,
    }

    // Events
    public struct CertificateIssued has copy, drop {
        certificate_id: address,
        recipient: address,
        issuer: address,
        certificate_type: String,
        issue_date: u64,
    }

    public struct IssuerCreated has copy, drop {
        issuer_cap_id: address,
        issuer_name: String,
        issuer_address: address,
    }

    // Initialize function - called once when module is published
    fun init(ctx: &mut sui::tx_context::TxContext) {
        // Create admin capability and transfer to publisher
        let admin_cap = AdminCap {
            id: sui::object::new(ctx),
        };
        sui::transfer::transfer(admin_cap, sui::tx_context::sender(ctx));
    }

    // Create a new issuer capability
    public entry fun create_issuer(
        _admin_cap: &AdminCap,
        issuer_name: vector<u8>,
        issuer_address: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let issuer_cap = IssuerCap {
            id: sui::object::new(ctx),
            issuer_name: std::string::utf8(issuer_name),
            issuer_address,
        };

        sui::event::emit(IssuerCreated {
            issuer_cap_id: sui::object::uid_to_address(&issuer_cap.id),
            issuer_name: issuer_cap.issuer_name,
            issuer_address,
        });

        sui::transfer::transfer(issuer_cap, issuer_address);
    }

    // Issue a certificate to a recipient
    public entry fun issue_certificate(
        issuer_cap: &IssuerCap,
        recipient: address,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        certificate_type: vector<u8>,
        metadata: vector<u8>,
        clock: &Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        // Verify the issuer
        assert!(issuer_cap.issuer_address == sui::tx_context::sender(ctx), ENotAuthorized);
        
        let certificate = Certificate {
            id: sui::object::new(ctx),
            name: std::string::utf8(name),
            description: std::string::utf8(description),
            image_url: std::string::utf8(image_url),
            recipient,
            issuer: issuer_cap.issuer_address,
            issue_date: sui::clock::timestamp_ms(clock),
            certificate_type: std::string::utf8(certificate_type),
            metadata: std::string::utf8(metadata),
        };

        sui::event::emit(CertificateIssued {
            certificate_id: sui::object::uid_to_address(&certificate.id),
            recipient,
            issuer: issuer_cap.issuer_address,
            certificate_type: certificate.certificate_type,
            issue_date: certificate.issue_date,
        });

        // Transfer directly to recipient - this makes it non-transferable
        // because there's no public transfer function for Certificate
        sui::transfer::transfer(certificate, recipient);
    }

    // Batch issue certificates
    public entry fun batch_issue_certificates(
        issuer_cap: &IssuerCap,
        recipients: vector<address>,
        names: vector<vector<u8>>,
        descriptions: vector<vector<u8>>,
        image_urls: vector<vector<u8>>,
        certificate_types: vector<vector<u8>>,
        metadatas: vector<vector<u8>>,
        clock: &Clock,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(issuer_cap.issuer_address == sui::tx_context::sender(ctx), ENotAuthorized);
        
        let len = std::vector::length(&recipients);
        let mut i = 0;
        
        while (i < len) {
            let recipient = *std::vector::borrow(&recipients, i);
            let name = *std::vector::borrow(&names, i);
            let description = *std::vector::borrow(&descriptions, i);
            let image_url = *std::vector::borrow(&image_urls, i);
            let certificate_type = *std::vector::borrow(&certificate_types, i);
            let metadata = *std::vector::borrow(&metadatas, i);
            
            let certificate = Certificate {
                id: sui::object::new(ctx),
                name: std::string::utf8(name),
                description: std::string::utf8(description),
                image_url: std::string::utf8(image_url),
                recipient,
                issuer: issuer_cap.issuer_address,
                issue_date: sui::clock::timestamp_ms(clock),
                certificate_type: std::string::utf8(certificate_type),
                metadata: std::string::utf8(metadata),
            };

            sui::event::emit(CertificateIssued {
                certificate_id: sui::object::uid_to_address(&certificate.id),
                recipient,
                issuer: issuer_cap.issuer_address,
                certificate_type: certificate.certificate_type,
                issue_date: certificate.issue_date,
            });

            sui::transfer::transfer(certificate, recipient);
            i = i + 1;
        }
    }

    // View functions for certificate data
    public fun get_certificate_name(certificate: &Certificate): String {
        certificate.name
    }

    public fun get_certificate_description(certificate: &Certificate): String {
        certificate.description
    }

    public fun get_certificate_image_url(certificate: &Certificate): String {
        certificate.image_url
    }

    public fun get_certificate_recipient(certificate: &Certificate): address {
        certificate.recipient
    }

    public fun get_certificate_issuer(certificate: &Certificate): address {
        certificate.issuer
    }

    public fun get_certificate_issue_date(certificate: &Certificate): u64 {
        certificate.issue_date
    }

    public fun get_certificate_type(certificate: &Certificate): String {
        certificate.certificate_type
    }

    public fun get_certificate_metadata(certificate: &Certificate): String {
        certificate.metadata
    }

    // Verify certificate authenticity
    public fun verify_certificate(certificate: &Certificate, expected_issuer: address): bool {
        certificate.issuer == expected_issuer
    }

    // Get issuer info
    public fun get_issuer_name(issuer_cap: &IssuerCap): String {
        issuer_cap.issuer_name
    }

    public fun get_issuer_address(issuer_cap: &IssuerCap): address {
        issuer_cap.issuer_address
    }

    // Emergency function to destroy a certificate (only by recipient)
    public entry fun destroy_certificate(certificate: Certificate, ctx: &sui::tx_context::TxContext) {
        assert!(certificate.recipient == sui::tx_context::sender(ctx), ENotAuthorized);
        let Certificate { 
            id, 
            name: _, 
            description: _, 
            image_url: _, 
            recipient: _, 
            issuer: _, 
            issue_date: _, 
            certificate_type: _, 
            metadata: _ 
        } = certificate;
        sui::object::delete(id);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut sui::tx_context::TxContext) {
        init(ctx);
    }
}