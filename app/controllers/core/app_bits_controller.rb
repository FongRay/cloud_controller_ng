require "cloud_controller/upload_handler"
require "jobs/runtime/app_bits_packer_job"

module VCAP::CloudController
  rest_controller :AppBits do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    def upload(guid)
      app = find_guid_and_validate_access(:update, guid)

      raise Errors::AppBitsUploadInvalid, "missing :resources" unless params["resources"]

      uploaded_zip_of_files_not_in_blobstore = UploadHandler.new(config).uploaded_file(params, "application")
      AppBitsPackerJob.new(guid, uploaded_zip_of_files_not_in_blobstore.try(:path), json_param("resources")).perform

      HTTP::CREATED
    rescue VCAP::CloudController::Errors::AppBitsUploadInvalid, VCAP::CloudController::Errors::AppPackageInvalid
      app.mark_as_failed_to_stage
      raise
    end

    def download(guid)
      find_guid_and_validate_access(:read, guid)

      package_uri = AppPackage.package_uri(guid)
      logger.debug "guid: #{guid} package_uri: #{package_uri}"

      if package_uri.nil?
        logger.error "could not find package for #{guid}"
        raise Errors::AppPackageNotFound.new(guid)
      end

      if AppPackage.blob_store.local?
        if config[:nginx][:use_nginx]
          return [200, { "X-Accel-Redirect" => "#{package_uri}" }, ""]
        else
          return send_file package_path, :filename => File.basename("#{path}.zip")
        end
      else
        return [HTTP::FOUND, {"Location" => package_uri}, nil]
      end
    end

    def json_param(name)
      raw = params[name]
      Yajl::Parser.parse(raw)
    rescue Yajl::ParseError
      raise Errors::AppBitsUploadInvalid.new("invalid :#{name}")
    end

    put "#{path_guid}/bits", :upload
    get "#{path_guid}/download", :download
  end
end
