# 1. Use the specific AWS base image for Python 3.11. 
# This image contains the necessary runtime components that allow the container to run as a Lambda function.
FROM public.ecr.aws/lambda/python:3.11

# 2. Set the working directory inside the container
WORKDIR /var/task

# 3. Copy application files into the container.
# This copies your lambda_handler.py and any other necessary files into the /var/task directory.
COPY lambda_handler.py .

# 4. (Optional but recommended) Install Python dependencies.
# If you had any dependencies (like the 'requests' library), they would be installed here.
# For simplicity, we assume you only need the 'boto3' library, which is pre-installed in the base image.
# If you had a requirements.txt, you would use:
# COPY requirements.txt .
# RUN pip install -r requirements.txt --target .

# 5. Define the command that Lambda will execute.
# This specifies the handler function in the format: [file_name].[function_name]
CMD ["lambda_handler.lambda_handler"]