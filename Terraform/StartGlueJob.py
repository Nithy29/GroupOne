import boto3
import os

def lambda_handler(event, context):
    # Define the Glue job name
    # glue_job_name = 'GetData'
    glue_job_name = os.environ['GLUE_JOB_NAME']
    

    # Create a Glue client
    glue_client = boto3.client('glue')

    try:
        # Start the Glue job
        response = glue_client.start_job_run(JobName=glue_job_name)

        # Print the job run details
        print("Job run started:", response)

        return {
            'statusCode': 200,
            'body': 'Glue job run started successfully!'
        }
    except Exception as e:
        print(f"Error starting Glue job: {e}")
        return {
            'statusCode': 500,
            'body': 'Error starting Glue job'
        }
