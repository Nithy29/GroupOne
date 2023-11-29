from flask import Flask, render_template, request, jsonify
import requests
import json

app = Flask(__name__)

# Replace these with your API Gateway endpoints
s3_upload_url = "https://d8dpqqn6gk.execute-api.ca-central-1.amazonaws.com/prod/Upload"
dynamodb_upload_url = "https://nj6k0aca96.execute-api.ca-central-1.amazonaws.com/prod/data"
startJob_url = "https://c9ejkwny1h.execute-api.ca-central-1.amazonaws.com/prod/invoke"

@app.route('/')
def index():
    return render_template('index.html')

# Upload an object s3Bucket
@app.route('/upload_to_s3', methods=['POST'])
def upload_to_s3():
    
    data = request.get_json()

    try:
        requests.post(s3_upload_url, json.dumps(data))
        return {
           'statusCode': 200,
           'body': 'File is uploaded to S3 Bucket!'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Unable to upload the file: {str(e)}'
        }    


# Start a glue job
@app.route('/Start_Glue_Job', methods=['POST'])
def Start_Glue_Job():

    try:
        requests.post(startJob_url)
        return {
           'statusCode': 200,
           'body': 'Glue job is started successfully!'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Unable to start the glue job: {str(e)}'
        }


# Create a record in DB
@app.route('/upload_to_dynamodb', methods=['POST'])
def upload_to_dynamodb():
    data = request.get_json()
    print(data)

    try:
        requests.post(dynamodb_upload_url, json.dumps(data))
        return {
           'statusCode': 200,
           'body': 'Record successfully written to DB!'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error writting the record to DB: {str(e)}'
        }


# Retrieve all entry from DB
@app.route('/dynamodb_all_entries', methods=['POST'])
def dynamodb_all_entries():
    data = request.get_json()
    response = requests.post(dynamodb_upload_url, json.dumps(data))
    return response.text


# Delete the selected records
@app.route('/delete_record', methods=['POST'])
def delete_record():
    data = request.get_json()
    record_id = data.get('id')

    DBOperation = f'{{"dynamoDB_action": "DELETE", "pathParameters": {{"id": "{record_id}"}}}}'
    print(DBOperation)

    # rsp = requests.post(dynamodb_upload_url, DBOperation)
    # print(rsp.text)
    # return rsp.text

    try:
        requests.post(dynamodb_upload_url, DBOperation)
        return {
           'statusCode': 200,
           'body': 'Record successfully deleted from DB!'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Unable to delete the record: {str(e)}'
        }
    


if __name__ == '_main_':
    app.run(debug=True, host='0.0.0.0',port=8080)