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

    def third_party_paid!(account_number)
      mod = self.soap_module

      contents.requestedShipment.shippingChargesPayment = mod::Payment.new.tap do |scp|
        scp.paymentType = mod::PaymentType::THIRD_PARTY

        scp.payor = mod::Payor.new
        scp.payor.responsibleParty.new.tap do |respParty|
          respParty.accountNumber = account_number
        end
      end
    end

    def regular_pickup!
      contents.requestedShipment.dropoffType = soap_module::DropoffType::REGULAR_PICKUP
    end

    def event_notification!(event, options = {})
      contents.requestedShipment.specialServicesRequested ||= soap_module::ShipmentSpecialServicesRequested.new
      contents.requestedShipment.specialServicesRequested.specialServiceTypes ||= []

      case event
        when :estimated_delivery
          contents.requestedShipment.specialServicesRequested.specialServiceTypes = (contents.requestedShipment.specialServicesRequested.specialServiceTypes + ['EVENT_NOTIFICATION']).uniq
          contents.requestedShipment.specialServicesRequested.eventNotificationDetail = soap_module::ShipmentEventNotificationDetail.new.tap do |detail|
            detail.aggregationType = soap_module::ShipmentNotificationAggregationType::PER_SHIPMENT
            detail.personalMessage = ''
            detail.eventNotifications = soap_module::ShipmentEventNotificationSpecification.new.tap do |notifications|
              notifications.role = soap_module::ShipmentNotificationRoleType::RECIPIENT
              notifications.events ||= []
              notifications.events = (notifications.events + [soap_module::NotificationEventType::ON_ESTIMATED_DELIVERY]).uniq
              notifications.notificationDetail = soap_module::NotificationDetail.new(
                soap_module::NotificationType::EMAIL,
                soap_module::EMailDetail.new(options[:email], options[:name]),
                soap_module::Localization.new('EN')
              )
              notifications.formatSpecification = soap_module::ShipmentNotificationFormatSpecification.new(
                soap_module::NotificationFormatType::HTML
              )
            end
          end
      end
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
      contents.requestedShipment.specialServicesRequested.specialServiceTypes = (contents.requestedShipment.specialServicesRequested.specialServiceTypes + ['ELECTRONIC_TRADE_DOCUMENTS']).uniq
      contents.requestedShipment.specialServicesRequested.etdDetail = mod::EtdDetail.new.tap do |etd|
        etd.documentReferences = mod::UploadDocumentReferenceDetail.new.tap do |ref|
          ref.documentProducer = mod::UploadDocumentProducerType::CUSTOMER
          ref.documentType = mod::UploadDocumentType::COMMERCIAL_INVOICE
          ref.documentId = document_id
          ref.documentIdProducer = mod::UploadDocumentIdProducer::CUSTOMER
        end
      end
    end

    def etd_minimal!
      mod = self.soap_module
      contents.requestedShipment.specialServicesRequested ||= mod::ShipmentSpecialServicesRequested.new
      contents.requestedShipment.specialServicesRequested.specialServiceTypes ||= []
      contents.requestedShipment.specialServicesRequested.specialServiceTypes = (contents.requestedShipment.specialServicesRequested.specialServiceTypes + ['ELECTRONIC_TRADE_DOCUMENTS']).uniq
      contents.requestedShipment.specialServicesRequested.etdDetail = mod::EtdDetail.new.tap do |etd|
        etd.attributes = mod::EtdAttributeType::POST_SHIPMENT_UPLOAD_REQUESTED
      end

      contents.shippingDocumentSpecification ||= mod::ShippingDocumentSpecification.new.tap do |sds|
        sds.shippingDocumentTypes = mod::RequestedShippingDocumentType::COMMERCIAL_INVOICE
      end
    end

    def self.shipment_requests(service_type, from, to, label_specification, package_weights, special_services_requested, dimensions)
      package_weights.map.with_index do |weight, ndx|
        new.tap do |request|
          mod = request.soap_module

          request.contents.requestedShipment = mod::RequestedShipment.new.tap do |rs|
            rs.shipTimestamp = Time.now.iso8601
            rs.serviceType   = service_type
            rs.packagingType = 'YOUR_PACKAGING'
            if ndx == 0
              rs.totalWeight = mod::Weight.new.tap do |w|
                w.units = "KG"
                w.value = package_weights.sum{|x| x.value}
              end
            end

            rs.shipper   = from
            rs.recipient = to
            rs.labelSpecification = label_specification

            rs.packageCount = package_weights.size
            rs.requestedPackageLineItems = mod::RequestedPackageLineItem.new.tap do |rpli|
              rpli.sequenceNumber = ndx + 1
              rpli.weight = weight
              rpli.specialServicesRequested = special_services_requested if special_services_requested
              rpli.dimensions = dimensions[ndx]
            end
          end
        end
      end
    end
  end
end
