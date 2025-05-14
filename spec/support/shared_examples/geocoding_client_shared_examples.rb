shared_examples "a geocoding client returning a location successfully" do
  it 'returns a Success object' do
    expect(result).to be_success
  end

  it 'contains a Location object in its data' do
    expect(result.data).to be_a(Location)
  end

  it 'provides a Location object with latitude and longitude' do
    expect(location.latitude).to be_a(Float)
    expect(location.longitude).to be_a(Float)
    expect(location.latitude).not_to be_nil
    expect(location.longitude).not_to be_nil
  end
end

shared_examples 'returns a Failure with InvalidInputError' do
  it 'returns a Failure with InvalidInputError' do
    result = client.geocode(address: blank_address)
    expect(result).to be_failure
    expect(result.error).to be_a(Errors::InvalidInputError)
    expect(result.error.message).to eq("Address cannot be blank")
  end

  it 'does not attempt an API call' do
    expect { client.geocode(address: blank_address) }.not_to raise_error
  end
end

shared_examples 'returns a Failure with NetworkError and logs' do
  it 'returns a Failure with NetworkError' do
    result = client.geocode(address: address)
    expect(result).to be_failure
    expect(result.error).to be_a(Errors::NetworkError)
  end

  it 'logs the network communication error' do
    client.geocode(address: address)
    expect(Rails.logger).to have_received(:error).with(
      include("[Network Communication]")
        .and(include("Faraday::TimeoutError - Connection timed out"))
        .and(include("#{expected_url}"))
    )
  end
end
