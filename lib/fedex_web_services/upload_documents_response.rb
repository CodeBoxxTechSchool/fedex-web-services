require 'base64'

module FedexWebServices
  class UploadDocumentsResponse < Response

    def document_ids
      contents.documentStatuses.select{|x| x.status == 'SUCCESS'}.collect{|x| x.documentId}
    rescue
      raise Api::ServiceException, "Unable to extract document_id from response"
    end

  end
end
