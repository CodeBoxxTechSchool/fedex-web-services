require 'fedex_web_services/process_shipment_response'

module FedexWebServices
  class ProcessShipmentRequest < Request
    def initialize
      @contents = soap_module::ProcessShipmentRequest.new
    end

    def soap_module
      FedexWebServices::Soap::Ship
    end

    def remote_method
      :processShipment
    end

    def endpoint_path
      '/web-services/ship'
    end

    def service_id
      :ship
    end

    def version
      26
    end

    def issue_request(port, credentials)
      ProcessShipmentResponse.new(port.send(remote_method, request_contents(credentials)))
    end

    def sender_paid!(account_number)
      mod = self.soap_module

      contents.requestedShipment.shippingChargesPayment = mod::Payment.new.tap do |scp|
        scp.paymentType = mod::PaymentType::SENDER

        scp.payor = mod::Payor.new
        scp.payor.responsibleParty = contents.requestedShipment.shipper.dup
        scp.payor.responsibleParty.accountNumber = account_number
      end
    end

    def regular_pickup!
      contents.requestedShipment.dropoffType = soap_module::DropoffType::REGULAR_PICKUP
    end

    def list_rate!
      contents.requestedShipment.rateRequestTypes = [ soap_module::RateRequestType::LIST ]
    end

    def for_master_tracking_number!(tracking_number)
      contents.requestedShipment.masterTrackingId = soap_module::TrackingId.new.tap do |ti|
        ti.trackingNumber = tracking_number
      end
    end

    def customer_reference!(reference)
      mod = self.soap_module
      ref = mod::CustomerReference.new(mod::CustomerReferenceType::CUSTOMER_REFERENCE, reference)

      contents.requestedShipment.requestedPackageLineItems.customerReferences ||= []
      contents.requestedShipment.requestedPackageLineItems.customerReferences << ref
    end

    def customer_invoice!(invoice_number)
      mod = self.soap_module
      ref = mod::CustomerReference.new(mod::CustomerReferenceType::INVOICE_NUMBER, invoice_number)

      contents.requestedShipment.requestedPackageLineItems.customerReferences ||= []
      contents.requestedShipment.requestedPackageLineItems.customerReferences << ref
    end

    def electronic_trade_documents!(document_id)
      mod = self.soap_module
      contents.requestedShipment.specialServicesRequested ||= mod::ShipmentSpecialServicesRequested.new
      contents.requestedShipment.specialServicesRequested.specialServiceTypes ||= []
      contents.requestedShipment.specialServicesRequested.specialServiceTypes << 'ELECTRONIC_TRADE_DOCUMENTS'
      contents.requestedShipment.specialServicesRequested.etdDetail = mod::EtdDetail.new.tap do |etd|
        etd.documentReferences = mod::UploadDocumentReferenceDetail.new.tap do |ref|
          ref.documentProducer = mod::UploadDocumentProducerType::CUSTOMER
          ref.documentType = mod::UploadDocumentType::COMMERCIAL_INVOICE
          ref.documentId = document_id
          ref.documentIdProducer = mod::UploadDocumentIdProducer::CUSTOMER
        end
      end
    end

    def self.shipment_requests(service_type, from, to, label_specification, package_weights)
      package_weights.map.with_index do |weight, ndx|
        new.tap do |request|
          mod = request.soap_module

          request.contents.requestedShipment = mod::RequestedShipment.new.tap do |rs|
            rs.shipTimestamp = Time.now.iso8601
            rs.serviceType   = service_type
            rs.packagingType = 'YOUR_PACKAGING'

            rs.shipper   = from
            rs.recipient = to

            rs.labelSpecification = label_specification

            rs.packageCount = package_weights.size
            rs.requestedPackageLineItems = mod::RequestedPackageLineItem.new.tap do |rpli|
              rpli.sequenceNumber = ndx + 1
              rpli.weight = weight
            end
          end
        end
      end
    end
  end
end
