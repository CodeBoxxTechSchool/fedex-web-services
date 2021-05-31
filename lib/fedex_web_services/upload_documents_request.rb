require 'fedex_web_services/upload_documents_response'

module FedexWebServices
  class UploadDocumentsRequest < Request
    
    def initialize
      @contents = soap_module::UploadDocumentsRequest.new
    end

    def soap_module
      FedexWebServices::Soap::UploadDocument
    end

    def endpoint_path
      '/web-services/uploaddocument'
    end

    def remote_method
      :uploadDocuments
    end

    def service_id
      :cdus
    end

    def version
      17
    end

    def issue_request(port, credentials)
      UploadDocumentsResponse.new(port.send(remote_method, request_contents(credentials)))
    end
  end
end
