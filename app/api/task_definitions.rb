require 'grape'
require 'task_serializer'

module Api
  class TaskDefinitions < Grape::API
    helpers AuthHelpers
    helpers AuthorisationHelpers

    before do
      authenticated?
    end

    desc "Add a new task definition to the given unit"
    params do
      group :task_def do
        requires :unit_id,              type: Integer,  :desc => "The unit to create the new task def for"
        requires :name,                 type: String,   :desc => "The name of this task def"
        requires :description,          type: String,   :desc => "The description of this task def"
        requires :weighting,            type: Integer,  :desc => "The weighting of this task"
        requires :required,             type: Boolean,  :desc => "Whether or not this task is required for the unit"
        requires :target_date,          type: Date,     :desc => "The date when the task is due"
        requires :abbreviation,         type: String,   :desc => "The abbreviation of the task"
        optional :upload_requirements,  type: String,     :desc => "Task file upload requirements"
      end
    end
    post '/task_definitions/' do      
      unit = Unit.find(params[:task_def][:unit_id]) 
      if not authorise? current_user, unit, :add_task_def
        error!({"error" => "Not authorised to create a task definition of this unit"}, 403)
      end
      
      params[:task_def][:upload_requirements] = "[]" if params[:task_def][:upload_requirements].nil?;
      
      task_params = ActionController::Parameters.new(params)
                                                .require(:task_def)
                                                .permit(
                                                  :unit_id,            
                                                  :name,               
                                                  :description,        
                                                  :weighting,          
                                                  :required,           
                                                  :target_date,        
                                                  :abbreviation,
                                                  :upload_requirements
                                                )
      TaskDefinition.create!(task_params)
      TaskDefinition.last
    end
    
    desc "Edits the given task definition"
    params do
      requires :id,                     type: Integer,  :desc => "The task id to edit"
      group :task_def do
        optional :unit_id,              type: Integer,  :desc => "The unit to create the new task def for"
        optional :name,                 type: String,   :desc => "The name of this task def"
        optional :description,          type: String,   :desc => "The description of this task def"
        optional :weighting,            type: Integer,  :desc => "The weighting of this task"
        optional :required,             type: Boolean,  :desc => "Whether or not this task is required for the unit"
        optional :target_date,          type: Date,     :desc => "The date when the task is due"
        optional :abbreviation,         type: String,   :desc => "The abbreviation of the task"
        optional :upload_requirements,  type: String,   :desc => "Task file upload requirements"
      end
    end
    put '/task_definitions/:id' do      
      task_def = TaskDefinition.find(params[:id])
      
      if not authorise? current_user, task_def.unit, :add_task_def
        error!({"error" => "Not authorised to create a task definition of this unit"}, 403)
      end
      
      task_params = ActionController::Parameters.new(params)
                                                .require(:task_def)
                                                .permit(
                                                  :unit_id,            
                                                  :name,               
                                                  :description,        
                                                  :weighting,          
                                                  :required,           
                                                  :target_date,        
                                                  :abbreviation,
                                                  :upload_requirements
                                                )
      task_def.update!(task_params)
      task_def
    end
    
    desc "Upload CSV of task definitions to the provided unit"
    params do
      requires :file, type: Rack::Multipart::UploadedFile, :desc => "CSV upload file."
      requires :unit_id, type: Integer, :desc => "The unit to upload tasks to"
    end
    post '/csv/task_definitions' do
      unit = Unit.find(params[:unit_id])
      
      if not authorise? current_user, unit, :uploadCSV
        error!({"error" => "Not authorised to upload CSV of users"}, 403)
      end
      
      # check mime is correct before uploading
      if not params[:file][:type] == "text/csv"
        error!({"error" => "File given is not a CSV file"}, 403)
      end
      
      # Actually import...
      unit.import_tasks_from_csv(params[:file][:tempfile])
    end
    
    desc "Download CSV of all task definitions for the given unit"
    params do
      requires :unit_id, type: Integer, :desc => "The unit to download tasks from"
    end
    get '/csv/task_definitions' do
      unit = Unit.find(params[:unit_id])

      if not authorise? current_user, unit, :downloadCSV
        error!({"error" => "Not authorised to upload CSV of users"}, 403)
      end

      content_type "application/octet-stream"
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-Tasks.csv "
      env['api.format'] = :binary
      unit.task_definitions_csv
    end
    
  end
end

